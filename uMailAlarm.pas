unit uMailAlarm;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.MMSystem,
  System.SysUtils, System.Classes, System.UITypes, System.IniFiles,
  System.SyncObjs, System.StrUtils, System.Math, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Menus,
  IdMessage;

const
  WM_SHOW_ALARMS = WM_USER + 101;

type
  TMailConfig = record
    Server: string;
    Port: Integer;
    SSLMode: Integer;          // 0 = şifresiz, 1 = SSL/TLS (995), 2 = STARTTLS (110)
    Username: string;
    Password: string;
    SenderAddress: string;
    Keywords: TArray<string>;
    CheckIntervalSec: Integer;
    PlaySoundEnabled: Boolean;
    StartMinimized: Boolean;
  end;

  TAlarmInfo = record
    UID: string;
    SenderInfo: string;
    Subject: string;
    DateStr: string;
    Body: string;
  end;

  TMailCheckThread = class(TThread)
  private
    FConfig: TMailConfig;
    FSeenUIDs: TStringList;
    FProcessedUIDs: TStringList;
    FAlarms: TList<TAlarmInfo>;
    FErrorMsg: string;
    FFoundCount: Integer;
    function ExtractBody(AMsg: TIdMessage): string;
    function MatchesKeyword(const AText: string): Boolean;
    function MatchesSender(const AAddress: string): Boolean;
    function BuildSeenKey(const AUID: string): string;
  protected
    procedure Execute; override;
  public
    constructor Create(const AConfig: TMailConfig; ASeenUIDs: TStrings);
    destructor Destroy; override;
    property Alarms: TList<TAlarmInfo> read FAlarms;
    property ProcessedUIDs: TStringList read FProcessedUIDs;
    property ErrorMsg: string read FErrorMsg;
    property FoundCount: Integer read FFoundCount;
  end;

  TfrmMain = class(TForm)
    lblStatus: TLabel;
    lblLastCheck: TLabel;
    lblInfo: TLabel;
    btnCheckNow: TButton;
    btnReload: TButton;
    btnHide: TButton;
    tmrCheck: TTimer;
    TrayIcon1: TTrayIcon;
    pmTray: TPopupMenu;
    miShow: TMenuItem;
    miCheckNow: TMenuItem;
    miReload: TMenuItem;
    miSep: TMenuItem;
    miExit: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure tmrCheckTimer(Sender: TObject);
    procedure TrayIcon1DblClick(Sender: TObject);
    procedure miShowClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure miReloadClick(Sender: TObject);
    procedure btnCheckNowClick(Sender: TObject);
    procedure btnHideClick(Sender: TObject);
  private
    FAppDir: string;
    FIniPath: string;
    FSeenPath: string;
    FConfig: TMailConfig;
    FConfigOK: Boolean;
    FSeenUIDs: TStringList;
    FThread: TMailCheckThread;
    FPendingAlarms: TList<TAlarmInfo>;
    FShowingAlarms: Boolean;
    FReallyClose: Boolean;
    procedure CreateSampleIni;
    function LoadConfig: Boolean;
    procedure ApplyConfig;
    procedure LoadSeenUIDs;
    procedure SaveSeenUIDs;
    procedure StartCheck;
    procedure ThreadTerminated(Sender: TObject);
    procedure ShowPendingAlarms;
    procedure ShowMainForm;
    procedure HideToTray;
    procedure SetStatus(const S: string);
    procedure WMShowAlarms(var Msg: TMessage); message WM_SHOW_ALARMS;
    procedure WMSysCommand(var Msg: TWMSysCommand); message WM_SYSCOMMAND;
    procedure WMQueryEndSession(var Msg: TWMQueryEndSession); message WM_QUERYENDSESSION;
  end;

var
  frmMain: TfrmMain;

procedure LogMsg(const S: string);

implementation

{$R *.dfm}

uses
  IdPOP3, IdSSLOpenSSL, IdSSLOpenSSLHeaders, IdText, IdMessageParts,
  IdExplicitTLSClientServerBase,
  uAlarmPopup;

var
  GLogLock: TCriticalSection;
  GLogPath: string;

{ ---------- Yardımcılar ---------- }

procedure LogMsg(const S: string);
var
  FS: TFileStream;
  Bytes, Pre: TBytes;
  IsNew: Boolean;
begin
  GLogLock.Enter;
  try
    try
      IsNew := not FileExists(GLogPath);
      if IsNew then
        FS := TFileStream.Create(GLogPath, fmCreate or fmShareDenyWrite)
      else
        FS := TFileStream.Create(GLogPath, fmOpenWrite or fmShareDenyWrite);
      try
        FS.Seek(0, soEnd);
        if IsNew then
        begin
          Pre := TEncoding.UTF8.GetPreamble;
          if Length(Pre) > 0 then
            FS.WriteBuffer(Pre[0], Length(Pre));
        end;
        Bytes := TEncoding.UTF8.GetBytes(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) +
          '  ' + S + sLineBreak);
        if Length(Bytes) > 0 then
          FS.WriteBuffer(Bytes[0], Length(Bytes));
      finally
        FS.Free;
      end;
    except
      // Log yazılamazsa uygulamayı durdurma
    end;
  finally
    GLogLock.Leave;
  end;
end;

function StripHtml(const AHtml: string): string;
var
  I: Integer;
  InTag: Boolean;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    InTag := False;
    for I := 1 to Length(AHtml) do
    begin
      if AHtml[I] = '<' then
        InTag := True
      else if AHtml[I] = '>' then
      begin
        InTag := False;
        SB.Append(' ');
      end
      else if not InTag then
        SB.Append(AHtml[I]);
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
  Result := StringReplace(Result, '&nbsp;', ' ', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll, rfIgnoreCase]);
  Result := Trim(Result);
end;

{ ---------- TMailCheckThread ---------- }

constructor TMailCheckThread.Create(const AConfig: TMailConfig; ASeenUIDs: TStrings);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FConfig := AConfig;
  FConfig.Keywords := Copy(AConfig.Keywords);
  FSeenUIDs := TStringList.Create;
  FSeenUIDs.Sorted := True;
  FSeenUIDs.Duplicates := dupIgnore;
  FSeenUIDs.AddStrings(ASeenUIDs);
  FProcessedUIDs := TStringList.Create;
  FAlarms := TList<TAlarmInfo>.Create;
end;

destructor TMailCheckThread.Destroy;
begin
  FAlarms.Free;
  FProcessedUIDs.Free;
  FSeenUIDs.Free;
  inherited Destroy;
end;

function TMailCheckThread.MatchesKeyword(const AText: string): Boolean;
var
  KW, NormalizedText: string;
begin
  Result := False;
  if AText = '' then
    Exit;
  // AnsiLowerCase Türkçe ve diğer Unicode karakterlerde güvenilir değildir.
  // INI UTF-8 olduğundan anahtar kelimeyi Unicode string üzerinde karşılaştır.
  NormalizedText := LowerCase(AText);
  for KW in FConfig.Keywords do
    if (KW <> '') and (Pos(LowerCase(KW), NormalizedText) > 0) then
      Exit(True);
end;

function TMailCheckThread.MatchesSender(const AAddress: string): Boolean;
var
  Sender, Item: string;
  Parts: TArray<string>;
begin
  Sender := Trim(AAddress);
  // Boş veya * değeri, tüm gönderenlerden gelen mailleri izler.
  if (Trim(FConfig.SenderAddress) = '') or (Trim(FConfig.SenderAddress) = '*') then
    Exit(True);
  Parts := FConfig.SenderAddress.Split([',', ';']);
  for Item in Parts do
    if SameText(Sender, Trim(Item)) then
      Exit(True);
  Result := False;
end;

function TMailCheckThread.BuildSeenKey(const AUID: string): string;
var
  KW: string;
begin
  // Anahtar kelime veya gönderen filtresi değişirse mevcut mailler yeni
  // kuralla bir kez yeniden değerlendirilir.
  Result := AUID + '|from=' + LowerCase(Trim(FConfig.SenderAddress)) + '|kw=';
  for KW in FConfig.Keywords do
    Result := Result + '[' + LowerCase(Trim(KW)) + ']';
end;

function TMailCheckThread.ExtractBody(AMsg: TIdMessage): string;
var
  I: Integer;
  Part: TIdMessagePart;
  HtmlText: string;
begin
  Result := '';
  HtmlText := '';
  if AMsg.MessageParts.Count = 0 then
  begin
    Result := AMsg.Body.Text;
    if ContainsText(AMsg.ContentType, 'html') then
      Result := StripHtml(Result);
    Exit;
  end;
  for I := 0 to AMsg.MessageParts.Count - 1 do
  begin
    Part := AMsg.MessageParts.Items[I];
    if Part is TIdText then
    begin
      if ContainsText(Part.ContentType, 'text/html') then
      begin
        if HtmlText = '' then
          HtmlText := TIdText(Part).Body.Text;
      end
      else if (Result = '') and ((Part.ContentType = '') or ContainsText(Part.ContentType, 'text/plain')) then
        Result := TIdText(Part).Body.Text;
    end;
  end;
  if (Result = '') and (HtmlText <> '') then
    Result := StripHtml(HtmlText);
  if Result = '' then
    Result := AMsg.Body.Text;
end;

procedure TMailCheckThread.Execute;
var
  POP3: TIdPOP3;
  SSL: TIdSSLIOHandlerSocketOpenSSL;
  Msg: TIdMessage;
  UIDLs: TStringList;
  I, MsgNo: Integer;
  RawUID, UID, SeenKey, Line, BodyText: string;
  Info: TAlarmInfo;
begin
  FErrorMsg := '';
  FFoundCount := 0;
  SSL := nil;
  Msg := nil;
  UIDLs := nil;
  POP3 := TIdPOP3.Create(nil);
  try
    try
      POP3.Host := FConfig.Server;
      POP3.Username := FConfig.Username;
      POP3.Password := FConfig.Password;
      POP3.ConnectTimeout := 15000;
      POP3.ReadTimeout := 30000;

      if FConfig.SSLMode <> 0 then
      begin
        SSL := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
        SSL.SSLOptions.Mode := sslmClient;
        SSL.SSLOptions.SSLVersions := [sslvTLSv1_1, sslvTLSv1_2];
        POP3.IOHandler := SSL;          // UseTLS'den ÖNCE atanmalı
        if FConfig.SSLMode = 2 then
          POP3.UseTLS := utUseRequireTLS
        else
          POP3.UseTLS := utUseImplicitTLS;
      end
      else
        POP3.UseTLS := utNoTLSSupport;
      POP3.Port := FConfig.Port;        // UseTLS portu değiştirebildiği için en son

      POP3.Connect;
      UIDLs := TStringList.Create;
      if not POP3.UIDL(UIDLs) then
        raise Exception.Create('POP3 sunucusu UIDL komutunu desteklemiyor.');
      LogMsg(Format('POP3: %d ileti bulundu.', [UIDLs.Count]));

      Msg := TIdMessage.Create(nil);
      for I := 0 to UIDLs.Count - 1 do
      begin
        if Terminated then
          Break;
        Line := UIDLs[I];
        POP3.ParseUIDL(Line, MsgNo, RawUID);
        if (MsgNo < 1) or (RawUID = '') then
        begin
          LogMsg('POP3 UIDL satırı çözümlenemedi: ' + UIDLs[I]);
          Continue;
        end;

        // POP3 sıra numarası silinen maillerden sonra değişebilir; UIDL kalıcıdır.
        UID := 'POP3:' + FConfig.Server + ':' + RawUID;
        SeenKey := BuildSeenKey(UID);
        if FSeenUIDs.IndexOf(SeenKey) >= 0 then
          Continue;

        Msg.Clear;
        try
          if not POP3.Retrieve(MsgNo, Msg) then
          begin
            LogMsg('POP3 ileti ' + IntToStr(MsgNo) + ' alınamadı, sonraki döngüde tekrar denenecek.');
            Continue;
          end;
        except
          on E: Exception do
          begin
            LogMsg('POP3 ileti ' + IntToStr(MsgNo) + ' okunurken hata: ' + E.Message);
            Continue;
          end;
        end;

        FProcessedUIDs.Add(SeenKey);
        if not MatchesSender(Msg.From.Address) then
        begin
          LogMsg('POP3 ileti gönderici filtresi dışında: ' + Msg.From.Address);
          Continue;
        end;
        Inc(FFoundCount);
        BodyText := ExtractBody(Msg);
        if MatchesKeyword(Msg.Subject) or MatchesKeyword(BodyText) then
        begin
          Info.UID := UID;
          Info.SenderInfo := Msg.From.Text;
          Info.Subject := Msg.Subject;
          if Msg.Date > 0 then
            Info.DateStr := FormatDateTime('dd.mm.yyyy hh:nn:ss', Msg.Date)
          else
            Info.DateStr := '';
          Info.Body := BodyText;
          FAlarms.Add(Info);
          LogMsg('ALARM: UID=' + UID + ' Konu=' + Msg.Subject);
        end
        else
          LogMsg('POP3 ileti anahtar kelime içermiyor: UID=' + UID + ' Konu=' + Msg.Subject);
      end;
    except
      on E: Exception do
        FErrorMsg := E.ClassName + ': ' + E.Message;
    end;
  finally
    try
      if POP3.Connected then
        POP3.Disconnect;
    except
      // bağlantı zaten kopmuş olabilir
    end;
    Msg.Free;
    UIDLs.Free;
    POP3.Free;
    SSL.Free;
  end;
end;

{ ---------- TfrmMain ---------- }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FAppDir := ExtractFilePath(ParamStr(0));
  FIniPath := FAppDir + 'MailAlarm.ini';
  FSeenPath := FAppDir + 'seen_uids.dat';
  IdOpenSSLSetLibPath(FAppDir);

  FSeenUIDs := TStringList.Create;
  FSeenUIDs.Sorted := True;
  FSeenUIDs.Duplicates := dupIgnore;
  FPendingAlarms := TList<TAlarmInfo>.Create;

  Caption := 'Mail Alarm';
  btnCheckNow.Caption := 'Şimdi Kontrol Et';
  btnReload.Caption := 'Ayarları Yükle';
  btnHide.Caption := 'Tepsiye Gizle';
  miShow.Caption := 'Göster';
  miCheckNow.Caption := 'Şimdi Kontrol Et';
  miReload.Caption := 'Ayarları Yeniden Yükle';
  miExit.Caption := 'Çık';
  lblLastCheck.Caption := 'Son kontrol: -';
  lblInfo.Caption := '';
  TrayIcon1.Icon.Assign(Application.Icon);
  TrayIcon1.Visible := True;

  LoadSeenUIDs;
  LogMsg('Uygulama başlatıldı.');
  FConfigOK := LoadConfig;
  ApplyConfig;
  if FConfigOK and FConfig.StartMinimized then
    Application.ShowMainForm := False;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  tmrCheck.Enabled := False;
  if Assigned(FThread) then
  begin
    FThread.OnTerminate := nil;
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  SaveSeenUIDs;
  FPendingAlarms.Free;
  FSeenUIDs.Free;
  LogMsg('Uygulama kapatıldı.');
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if not FReallyClose then
  begin
    CanClose := False;
    HideToTray;
  end;
end;

procedure TfrmMain.CreateSampleIni;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Add('; Mail Alarm yapılandırma dosyası');
    SL.Add('; UseSSL: 0 = şifresiz, 1 = SSL/TLS (port 995), 2 = STARTTLS (port 110)');
    SL.Add('[POP3]');
    SL.Add('Server=pop.gmail.com');
    SL.Add('Port=995');
    SL.Add('UseSSL=1');
    SL.Add('Username=kullanici@gmail.com');
    SL.Add('Password=uygulama_sifresi');
    SL.Add('');
    SL.Add('[Filter]');
    SL.Add('SenderAddress=alarm@example.com');
    SL.Add('Keywords=ALARM,HATA,KRİTİK,ERROR,CRITICAL');
    SL.Add('CheckIntervalSeconds=60');
    SL.Add('');
    SL.Add('[App]');
    SL.Add('PlaySound=1');
    SL.Add('StartMinimized=1');
    try
      SL.SaveToFile(FIniPath, TEncoding.UTF8);
      LogMsg('Örnek INI oluşturuldu: ' + FIniPath);
      MessageDlg('Yapılandırma dosyası bulunamadı, örnek dosya oluşturuldu:' + sLineBreak +
        FIniPath + sLineBreak + sLineBreak +
        'Lütfen IMAP bilgilerini, gönderen adresini ve anahtar kelimeleri düzenleyip ' +
        '"Ayarları Yükle" butonuna basın.', mtInformation, [mbOK], 0);
    except
      on E: Exception do
      begin
        LogMsg('Örnek INI oluşturulamadı: ' + E.Message);
        MessageDlg('Örnek INI dosyası oluşturulamadı: ' + E.Message, mtError, [mbOK], 0);
      end;
    end;
  finally
    SL.Free;
  end;
end;

function TfrmMain.LoadConfig: Boolean;
var
  Ini: TMemIniFile;
  Parts, List: TArray<string>;
  I, N: Integer;
  S, Problems: string;
begin
  Result := False;
  if not FileExists(FIniPath) then
  begin
    CreateSampleIni;
    Exit;
  end;
  try
    Ini := TMemIniFile.Create(FIniPath, TEncoding.UTF8);
    try
      FConfig.Server := Trim(Ini.ReadString('POP3', 'Server', ''));
      FConfig.Port := Ini.ReadInteger('POP3', 'Port', 995);
      FConfig.SSLMode := EnsureRange(Ini.ReadInteger('POP3', 'UseSSL', 1), 0, 2);
      FConfig.Username := Trim(Ini.ReadString('POP3', 'Username', ''));
      FConfig.Password := Ini.ReadString('POP3', 'Password', '');
      FConfig.SenderAddress := Trim(Ini.ReadString('Filter', 'SenderAddress', ''));
      Parts := Ini.ReadString('Filter', 'Keywords', '').Split([',', ';']);
      SetLength(List, Length(Parts));
      N := 0;
      for I := 0 to High(Parts) do
      begin
        S := Trim(Parts[I]);
        if S <> '' then
        begin
          List[N] := S;
          Inc(N);
        end;
      end;
      SetLength(List, N);
      FConfig.Keywords := List;
      FConfig.CheckIntervalSec := Max(10, Ini.ReadInteger('Filter', 'CheckIntervalSeconds', 60));
      FConfig.PlaySoundEnabled := Ini.ReadBool('App', 'PlaySound', True);
      FConfig.StartMinimized := Ini.ReadBool('App', 'StartMinimized', True);
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
    begin
      LogMsg('INI okunamadı: ' + E.Message);
      MessageDlg('INI dosyası okunamadı: ' + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;

  Problems := '';
  if FConfig.Server = '' then
    Problems := Problems + '- [POP3] Server boş' + sLineBreak;
  if (FConfig.Username = '') or SameText(FConfig.Username, 'kullanici@gmail.com') then
    Problems := Problems + '- [POP3] Username girilmemiş' + sLineBreak;
  if (FConfig.Password = '') or (FConfig.Password = 'uygulama_sifresi') then
    Problems := Problems + '- [POP3] Password girilmemiş' + sLineBreak;
  if Length(FConfig.Keywords) = 0 then
    Problems := Problems + '- [Filter] Keywords boş' + sLineBreak;
  if Problems <> '' then
  begin
    LogMsg('Yapılandırma eksik: ' + StringReplace(Problems, sLineBreak, ' ', [rfReplaceAll]));
    MessageDlg('MailAlarm.ini yapılandırması eksik:' + sLineBreak + sLineBreak + Problems +
      sLineBreak + 'Dosyayı düzenleyip "Ayarları Yükle" butonuna basın.', mtWarning, [mbOK], 0);
    Exit;
  end;
  Result := True;
end;

procedure TfrmMain.ApplyConfig;
begin
  tmrCheck.Enabled := False;
  if FConfigOK then
  begin
    tmrCheck.Interval := FConfig.CheckIntervalSec * 1000;
    tmrCheck.Enabled := True;
    lblInfo.Caption := Format('Gönderen: %s  |  Aralık: %d sn', [FConfig.SenderAddress, FConfig.CheckIntervalSec]);
    SetStatus('İzleniyor: ' + FConfig.Username);
    StartCheck;
  end
  else
  begin
    lblInfo.Caption := 'INI: ' + FIniPath;
    SetStatus('Yapılandırma eksik - izleme durduruldu.');
  end;
end;

procedure TfrmMain.LoadSeenUIDs;
var
  SL: TStringList;
  I: Integer;
begin
  if not FileExists(FSeenPath) then
    Exit;
  SL := TStringList.Create;
  try
    try
      SL.LoadFromFile(FSeenPath);
      for I := 0 to SL.Count - 1 do
        if Trim(SL[I]) <> '' then
          FSeenUIDs.Add(Trim(SL[I]));
    except
      on E: Exception do
        LogMsg('seen_uids.dat okunamadı: ' + E.Message);
    end;
  finally
    SL.Free;
  end;
end;

procedure TfrmMain.SaveSeenUIDs;
begin
  try
    FSeenUIDs.SaveToFile(FSeenPath);
  except
    on E: Exception do
      LogMsg('seen_uids.dat yazılamadı: ' + E.Message);
  end;
end;

procedure TfrmMain.StartCheck;
begin
  if not FConfigOK then
    Exit;
  if Assigned(FThread) then
  begin
    if FThread.Finished then
      FreeAndNil(FThread)
    else
      Exit; // önceki kontrol hâlâ sürüyor
  end;
  SetStatus('Kontrol ediliyor...');
  FThread := TMailCheckThread.Create(FConfig, FSeenUIDs);
  FThread.OnTerminate := ThreadTerminated;
  FThread.Start;
end;

procedure TfrmMain.ThreadTerminated(Sender: TObject);
var
  T: TMailCheckThread;
  UID: string;
  A: TAlarmInfo;
begin
  T := Sender as TMailCheckThread;
  lblLastCheck.Caption := 'Son kontrol: ' + FormatDateTime('dd.mm.yyyy hh:nn:ss', Now);
  for UID in T.ProcessedUIDs do
    FSeenUIDs.Add(UID);
  if T.ProcessedUIDs.Count > 0 then
    SaveSeenUIDs;
  if T.ErrorMsg <> '' then
  begin
    LogMsg('IMAP hatası: ' + T.ErrorMsg);
    SetStatus('Hata (sonraki döngüde tekrar denenecek): ' + T.ErrorMsg);
  end
  else
    SetStatus(Format('İzleniyor - yeni mail: %d, alarm: %d', [T.FoundCount, T.Alarms.Count]));
  for A in T.Alarms do
    FPendingAlarms.Add(A);
  if FPendingAlarms.Count > 0 then
    PostMessage(Handle, WM_SHOW_ALARMS, 0, 0);
end;

procedure TfrmMain.WMShowAlarms(var Msg: TMessage);
begin
  ShowPendingAlarms;
end;

procedure TfrmMain.ShowPendingAlarms;
var
  A: TAlarmInfo;
begin
  if FShowingAlarms then
    Exit; // döngü zaten çalışıyor; yeni alarmlar sıraya eklendi
  FShowingAlarms := True;
  try
    while FPendingAlarms.Count > 0 do
    begin
      A := FPendingAlarms[0];
      FPendingAlarms.Delete(0);
      if FConfig.PlaySoundEnabled then
        PlaySound('SystemHand', 0, SND_ALIAS or SND_ASYNC);
      TrayIcon1.BalloonTitle := 'Mail Alarm';
      TrayIcon1.BalloonHint := Copy(A.Subject, 1, 200);
      TrayIcon1.ShowBalloonHint;
      try
        TfrmAlarmPopup.ShowAlarm(A.SenderInfo, A.Subject, A.DateStr, A.Body);
      except
        on E: Exception do
          LogMsg('Alarm penceresi gösterilemedi: ' + E.Message);
      end;
    end;
  finally
    FShowingAlarms := False;
  end;
end;

procedure TfrmMain.tmrCheckTimer(Sender: TObject);
begin
  StartCheck;
end;

procedure TfrmMain.SetStatus(const S: string);
begin
  lblStatus.Caption := S;
  TrayIcon1.Hint := Copy('Mail Alarm - ' + S, 1, 120);
end;

procedure TfrmMain.ShowMainForm;
begin
  Show;
  WindowState := wsNormal;
  BringToFront;
  SetForegroundWindow(Handle);
end;

procedure TfrmMain.HideToTray;
begin
  Hide;
end;

procedure TfrmMain.TrayIcon1DblClick(Sender: TObject);
begin
  ShowMainForm;
end;

procedure TfrmMain.miShowClick(Sender: TObject);
begin
  ShowMainForm;
end;

procedure TfrmMain.miExitClick(Sender: TObject);
begin
  FReallyClose := True;
  Close;
end;

procedure TfrmMain.miReloadClick(Sender: TObject);
begin
  FConfigOK := LoadConfig;
  ApplyConfig;
  LogMsg('Ayarlar yeniden yüklendi. Geçerli: ' + BoolToStr(FConfigOK, True));
end;

procedure TfrmMain.btnCheckNowClick(Sender: TObject);
begin
  if FConfigOK then
    StartCheck
  else
    MessageDlg('Yapılandırma eksik. Önce MailAlarm.ini dosyasını düzenleyin.', mtWarning, [mbOK], 0);
end;

procedure TfrmMain.btnHideClick(Sender: TObject);
begin
  HideToTray;
end;

procedure TfrmMain.WMSysCommand(var Msg: TWMSysCommand);
begin
  if (Msg.CmdType and $FFF0) = SC_MINIMIZE then
    HideToTray
  else
    inherited;
end;

procedure TfrmMain.WMQueryEndSession(var Msg: TWMQueryEndSession);
begin
  FReallyClose := True; // Windows kapanırken engelleme
  inherited;
end;

initialization
  GLogLock := TCriticalSection.Create;
  GLogPath := ExtractFilePath(ParamStr(0)) + 'MailAlarm.log';

finalization
  GLogLock.Free;

end.
