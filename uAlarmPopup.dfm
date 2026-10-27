object frmAlarmPopup: TfrmAlarmPopup
  Left = 0
  Top = 0
  ActiveControl = btnOK
  BorderStyle = bsDialog
  Caption = 'ALARM'
  ClientHeight = 460
  ClientWidth = 600
  Color = 192
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWhite
  Font.Height = -15
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 20
  object lblTitle: TLabel
    Left = 0
    Top = 10
    Width = 600
    Height = 56
    Alignment = taCenter
    AutoSize = False
    Caption = 'ALARM'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -40
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblSenderCap: TLabel
    Left = 20
    Top = 80
    Width = 90
    Height = 20
    AutoSize = False
    Caption = 'Gonderen:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -15
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblSender: TLabel
    Left = 115
    Top = 80
    Width = 465
    Height = 20
    AutoSize = False
    Caption = '-'
  end
  object lblSubjectCap: TLabel
    Left = 20
    Top = 108
    Width = 90
    Height = 20
    AutoSize = False
    Caption = 'Konu:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -15
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblSubject: TLabel
    Left = 115
    Top = 108
    Width = 465
    Height = 42
    AutoSize = False
    Caption = '-'
    WordWrap = True
  end
  object lblDateCap: TLabel
    Left = 20
    Top = 156
    Width = 90
    Height = 20
    AutoSize = False
    Caption = 'Tarih:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -15
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblDate: TLabel
    Left = 115
    Top = 156
    Width = 465
    Height = 20
    AutoSize = False
    Caption = '-'
  end
  object lblBodyCap: TLabel
    Left = 20
    Top = 184
    Width = 300
    Height = 20
    AutoSize = False
    Caption = 'Icerik:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -15
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object memBody: TMemo
    Left = 20
    Top = 206
    Width = 560
    Height = 192
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clBlack
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object btnOK: TButton
    Left = 240
    Top = 410
    Width = 120
    Height = 36
    Cancel = True
    Caption = 'Tamam'
    Default = True
    ModalResult = 1
    TabOrder = 0
    OnClick = btnOKClick
  end
end
