object fMain: TfMain
  Left = 182
  Top = 124
  Caption = 'Sorter'
  ClientHeight = 113
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
    Top = 94
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
      Caption = 'Please select the file...'
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'Arial'
      Font.Style = []
      ParentFont = False
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
        Top = 15
        Width = 129
        Height = 29
        Caption = 'Choose'
        TabOrder = 0
        OnClick = b_FindFileClick
      end
    end
  end
  object cb_MultiThread: TCheckBox
    Left = 23
    Top = 63
    Width = 298
    Height = 17
    Caption = 'Multithreaded sort'
    Checked = True
    State = cbChecked
    TabOrder = 2
    Visible = False
  end
  object od_InputFile: TOpenDialog
    Left = 192
    Top = 56
  end
end
