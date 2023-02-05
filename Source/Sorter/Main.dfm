object fMain: TfMain
  Left = 182
  Top = 124
  Caption = #1057#1086#1088#1090#1080#1088#1086#1074#1097#1080#1082
  ClientHeight = 391
  ClientWidth = 1506
  Color = clBtnFace
  Font.Charset = RUSSIAN_CHARSET
  Font.Color = clWindowText
  Font.Height = -16
  Font.Name = 'Arial'
  Font.Style = []
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnResize = FormResize
  PixelsPerInch = 96
  TextHeight = 18
  object sb_Main: TStatusBar
    Left = 0
    Top = 372
    Width = 1506
    Height = 19
    Panels = <
      item
        Width = 800
      end
      item
        Width = 50
      end>
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 1506
    Height = 57
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object l_FilePath: TLabel
      Left = 15
      Top = 25
      Width = 769
      Height = 41
      AutoSize = False
      Caption = '  '#1055#1086#1078#1072#1083#1091#1081#1089#1090#1072' '#1074#1099#1073#1077#1088#1080#1090#1077' '#1092#1072#1081#1083'...'
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'Arial'
      Font.Style = []
      ParentFont = False
      OnClick = l_FilePathClick
    end
    object Panel2: TPanel
      Left = 1367
      Top = 0
      Width = 139
      Height = 57
      Align = alRight
      BevelOuter = bvNone
      TabOrder = 0
      object b_FindFile: TButton
        Left = 0
        Top = 20
        Width = 129
        Height = 29
        Caption = #1042#1099#1073#1088#1072#1090#1100
        TabOrder = 0
        OnClick = b_FindFileClick
      end
    end
  end
  object od_InputFile: TOpenDialog
    Left = 192
    Top = 56
  end
end
