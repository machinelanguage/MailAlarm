program MailAlarm;

uses
  Winapi.Windows,
  Vcl.Forms,
  uMailAlarm in 'uMailAlarm.pas' {frmMain},
  uAlarmPopup in 'uAlarmPopup.pas' {frmAlarmPopup};

{$R *.res}

var
  hMutex: THandle;

begin
  // Tek örnek (single instance) kontrolü
  hMutex := CreateMutex(nil, False, 'MailAlarm_SingleInstance_Mutex_7F3A');
  if (hMutex <> 0) and (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    CloseHandle(hMutex);
    Exit;
  end;
  try
    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    Application.Title := 'Mail Alarm';
    Application.CreateForm(TfrmMain, frmMain);
    Application.Run;
  finally
    if hMutex <> 0 then
      CloseHandle(hMutex);
  end;
end.
