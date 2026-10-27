object frmMain: TfrmMain
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'Mail Alarm'
  ClientHeight = 160
  ClientWidth = 440
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 15
  object lblStatus: TLabel
    Left = 16
    Top = 16
    Width = 408
    Height = 36
    AutoSize = False
    Caption = 'Status'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
    WordWrap = True
  end
  object lblLastCheck: TLabel
    Left = 16
    Top = 60
    Width = 408
    Height = 15
    AutoSize = False
    Caption = '-'
  end
  object lblInfo: TLabel
    Left = 16
    Top = 82
    Width = 408
    Height = 15
    AutoSize = False
    Caption = '-'
  end
  object btnCheckNow: TButton
    Left = 16
    Top = 112
    Width = 130
    Height = 30
    Caption = 'Check now'
    TabOrder = 0
    OnClick = btnCheckNowClick
  end
  object btnReload: TButton
    Left = 155
    Top = 112
    Width = 130
    Height = 30
    Caption = 'Reload'
    TabOrder = 1
    OnClick = miReloadClick
  end
  object btnHide: TButton
    Left = 294
    Top = 112
    Width = 130
    Height = 30
    Caption = 'Hide'
    TabOrder = 2
    OnClick = btnHideClick
  end
  object tmrCheck: TTimer
    Enabled = False
    Interval = 60000
    OnTimer = tmrCheckTimer
    Left = 360
    Top = 8
  end
  object TrayIcon1: TTrayIcon
    Hint = 'Mail Alarm'
    PopupMenu = pmTray
    Visible = True
    OnDblClick = TrayIcon1DblClick
    Left = 392
    Top = 8
  end
  object pmTray: TPopupMenu
    Left = 328
    Top = 8
    object miShow: TMenuItem
      Caption = 'Show'
      OnClick = miShowClick
    end
    object miCheckNow: TMenuItem
      Caption = 'Check now'
      OnClick = btnCheckNowClick
    end
    object miReload: TMenuItem
      Caption = 'Reload'
      OnClick = miReloadClick
    end
    object miSep: TMenuItem
      Caption = '-'
    end
    object miExit: TMenuItem
      Caption = 'Exit'
      OnClick = miExitClick
    end
  end
end
