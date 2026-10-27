unit uAlarmPopup;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls;

type
  TfrmAlarmPopup = class(TForm)
    lblTitle: TLabel;
    lblSenderCap: TLabel;
    lblSender: TLabel;
    lblSubjectCap: TLabel;
    lblSubject: TLabel;
    lblDateCap: TLabel;
    lblDate: TLabel;
    lblBodyCap: TLabel;
    memBody: TMemo;
    btnOK: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FSenderInfo: string;
    FSubject: string;
    FDateStr: string;
    FBody: string;
    procedure SetSenderInfo(const Value: string);
    procedure SetSubject(const Value: string);
    procedure SetDateStr(const Value: string);
    procedure SetBody(const Value: string);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    property SenderInfo: string read FSenderInfo write SetSenderInfo;
    property Subject: string read FSubject write SetSubject;
    property DateStr: string read FDateStr write SetDateStr;
    property Body: string read FBody write SetBody;
    class procedure ShowAlarm(const ASender, ASubject, ADate, ABody: string);
  end;

implementation

{$R *.dfm}

const
  MAX_BODY_CHARS = 500;

procedure TfrmAlarmPopup.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := Params.ExStyle or WS_EX_TOPMOST or WS_EX_APPWINDOW;
end;

procedure TfrmAlarmPopup.FormCreate(Sender: TObject);
begin
  Caption := 'Mail Alarm - ALARM';
  lblTitle.Caption := #$D83D#$DD14 + ' ALARM';
  lblSenderCap.Caption := 'Gönderen:';
  lblSubjectCap.Caption := 'Konu:';
  lblDateCap.Caption := 'Tarih:';
  lblBodyCap.Caption := 'İçerik (ilk 500 karakter):';
  btnOK.Caption := 'Tamam';
end;

procedure TfrmAlarmPopup.FormShow(Sender: TObject);
begin
  SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
  SetForegroundWindow(Handle);
  FlashWindow(Handle, True);
  if btnOK.CanFocus then
    btnOK.SetFocus;
end;

procedure TfrmAlarmPopup.btnOKClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TfrmAlarmPopup.SetSenderInfo(const Value: string);
begin
  FSenderInfo := Value;
  lblSender.Caption := Value;
end;

procedure TfrmAlarmPopup.SetSubject(const Value: string);
begin
  FSubject := Value;
  lblSubject.Caption := Value;
end;

procedure TfrmAlarmPopup.SetDateStr(const Value: string);
begin
  FDateStr := Value;
  lblDate.Caption := Value;
end;

procedure TfrmAlarmPopup.SetBody(const Value: string);
var
  S: string;
begin
  FBody := Value;
  S := Trim(Value);
  if Length(S) > MAX_BODY_CHARS then
    S := Copy(S, 1, MAX_BODY_CHARS) + '...';
  memBody.Lines.Text := AdjustLineBreaks(S, tlbsCRLF);
  memBody.SelStart := 0;
end;

class procedure TfrmAlarmPopup.ShowAlarm(const ASender, ASubject, ADate, ABody: string);
var
  F: TfrmAlarmPopup;
begin
  F := TfrmAlarmPopup.Create(nil);
  try
    F.SenderInfo := ASender;
    F.Subject := ASubject;
    F.DateStr := ADate;
    F.Body := ABody;
    F.ShowModal;
  finally
    F.Free;
  end;
end;

end.
