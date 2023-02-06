unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls,

  Math;

const WM_MY_GEN_INFO = WM_USER + 1;

type
  DictArr    = Array of String;


//.............................. TThGenerator ..................................

  TThGenerator = class(TThread)
  private
    fMes,
    fFilePath
                 : String;

    fPbCurPos, fPbOldPos,                                                       // Variable for progressbar
    fFsCurSize,                                                                 // Current file size
    fFsMaxSize                                                                  // Maximum file size
                 : Int64;

    fOwerWrite   : Boolean;                                                     // Overwriting a file or writing to the end of a file

    fPDictionary : DictArr;                                                     // Dictionary, read-only

    fArrRndDict  : TStringList;                                                 // Container for generated data

    procedure GenerateBlock;                                                    // Data generator for writing to a file
    procedure SaveToFile;                                                       // Writing the generated data to a file

    function GetStartFileSize( FileName: string;                                // File size determinant for additional recording
                               Overwriting : Boolean = true): Int64;            // File size determinant for additional recording
    function MakeMemSize(Size: Int64): String;

  public
    property AMaxSize     : Int64   write FFsMaxSize;
    property AMes         : String  write FMes;
    property APDictionary : DictArr write FPDictionary;
    property AFilePath    : String  write fFilePath;
    property AOwerWrite   : Boolean write fOwerWrite;

    Procedure ShowProgress;                                                     // Synchronization function with the main window interface

    constructor Create();
    destructor Destroy; override ;
  protected
    procedure Execute; override;
  end;

//..............................................................................



  TfMain = class(TForm)
    sb_Main       : TStatusBar;
    Panel1        : TPanel;
    tb_FileSize   : TTrackBar;
    Panel2        : TPanel;
    b_Generate    : TButton;
    l_FileSize    : TLabel;
    m_Dictionary  : TMemo;
    chb_OwerWriting: TCheckBox;

    procedure tb_FileSizeChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure b_GenerateClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormResize(Sender: TObject);
  private
    Procedure DictionaryPrepare();
    procedure WMOnWM_MYINFO(var msg: TMessage); message WM_MY_GEN_INFO;         // Processing messages from a stream
  public
    FilePath   : String;
    pb_Main    : TProgressBar;
    l_PbInfo   : TLabel;
    Dictionary : DictArr;
  end;

var
  fMain         : TfMain;
  thGen         : TThGenerator;

const
  MIN_FILESIZE    = 536870912;                                                  // Minimum file size in bytes
  MAX_FILESIZE    = 10737418240;                                                // Maximum file size in bytes
  FILE_NAME       = 'result.txt';                                               // Name of the file being created
  MAX_INT_RANGE   = 99999;                                                      // Random size for Number

implementation

{$R *.dfm}


procedure TfMain.WMOnWM_MYINFO(var msg: TMessage);                              // Message handler from the stream
var
  msgType,
  msgVal
                  : Integer;
begin
  msgType := msg.wParam;
  msgVal  := msg.lParam;

  case msgType of

    1: // The option of moving the progres bar
       Begin
         // PbShowMessage(msgVal, '');
       End;

    2: // Information received from the stream
       Begin
         case msgVal of

           1..2 : // Completed or interrupted without an accident
                 Begin
                   fMain.tb_FileSize.Enabled     := true;
                   fMain.b_Generate.Enabled      := true;
                   fMain.chb_OwerWriting.enabled := true;
                   fMain.b_Generate.Caption      := 'Generate';

                   if FileExists(FilePath) then
                   Begin
                     chb_OwerWriting.visible := true;
                   End;
                 End;

           3 :   // The thread is destroyed in the destructor
                 Begin
                   thGen := nil;
                 End;

           4 :   // When re-recording, the user specified a size smaller than the original one
                 Begin
                   if MessageDlg('The selected size exceeds the existing file size! Rewrite it?', mtError, mbOKCancel, 0) = mrOK then
                   Begin
                     fMain.chb_OwerWriting.checked := true;
                     fMain.b_Generate.Caption      := 'Generate';
                     fMain.b_Generate.Click;
                   End
                   else
                   Begin
                     fMain.tb_FileSize.Enabled     := true;
                     fMain.b_Generate.Enabled      := true;
                     fMain.chb_OwerWriting.enabled := true;
                     fMain.b_Generate.Caption      := 'Generate';
                   End;
                 End;
         end;

       End;
  end;

End;


// Creation, completion of the stream
procedure TfMain.b_GenerateClick(Sender: TObject);                              // b_Generate
var
  fileSize  : Int64;
  owerWrite : Boolean;
begin
  if FileExists(FilePath) then                                                
  Begin
    chb_OwerWriting.visible := true;
  End;

  if fMain.b_Generate.Caption = 'Generate' then
  Begin
    // Unblocks at the end of the stream -WMOnWM_MYINFO
    fMain.tb_FileSize.Enabled     := false;
    fMain.chb_OwerWriting.enabled := false;
    fMain.b_Generate.Caption      := 'Abort';

    fileSize     := fMain.tb_FileSize.Position;
    fileSize     := fileSize *(1024*1024);
    pb_Main.Max  := 100;
    owerWrite    := chb_OwerWriting.Checked;

    if not Assigned(thGen) then
    Begin
      thGen    := TThGenerator.Create();
      try
        // Passing parameters to the stream
        thGen.AMes         := '';
        thGen.APDictionary := Dictionary;
        thGen.AMaxSize     := fileSize;
        thGen.AFilePath    := FilePath;
        thGen.AOwerWrite   := owerWrite;
      finally
        thGen.Resume;
      end;
    end;

  end
  else
  Begin
    if Assigned(thGen) then
    Begin
      thGen.Terminate;
    End;
  end;
end;





//++++++++++++++++++++++++++  TThGenerator  ++++++++++++++++++++++++++++++++++++

Procedure TThGenerator.Execute;                                                 // TThGenerator.Execute
var
  i  : Integer;
Begin
  fFsCurSize   := GetStartFileSize(fFilePath, fOwerWrite);
  while fFsCurSize <= fFsMaxSize do
  Begin
    If Terminated then
    Begin
      fMes := 'Operation aborted!';
      Synchronize(ShowProgress);
      // Message - Operation aborted
      PostMessage( fMain.Handle, WM_MY_GEN_INFO, 2, 2 );
      break;
    End;

    GenerateBlock();

    fPbCurPos := round(fFsCurSize * 100/ fFsMaxSize);
    if fPbCurPos <>  fPbOldPos then
    Begin
      fPbOldPos := fPbCurPos;
      fMes := MakeMemSize(fFsCurSize);
      Synchronize(ShowProgress);
    End;

    //PostMessage( fMain.Handle, WM_MYINFO, 1, i );
  End;

  if fFsCurSize > ( fFsMaxSize + length(FPDictionary) * 255 ) then
  Begin
    // The message about the incorrect size before the recorded file
    PostMessage( fMain.Handle, WM_MY_GEN_INFO, 2, 4 );
    exit;
  End;

  fPbCurPos := 0;
  fMes := 'The operation is completed! - The file is located ->' + fFilePath;
  Synchronize(ShowProgress);

  // Message - Operation completed
  PostMessage( fMain.Handle, WM_MY_GEN_INFO, 2, 1 );
End;





constructor TThGenerator.Create();
Begin
  Randomize;
  fOwerWrite      := true;
  Inherited Create(True) ;
  FreeOnTerminate := true;
End;

destructor TThGenerator.Destroy;
Begin
  SetLength( FPDictionary, 0 );

  // Message - Can be released, the thread has finished
  PostMessage( fMain.Handle, WM_MY_GEN_INFO, 2, 3 );
End;



Procedure TThGenerator.GenerateBlock();                                         // GenerateBlock - Generating a block of strings based on the dictionary
var
  rndInt,
  rndStr,
  maxRange,
  i
                : Integer;
  strValue
                : String;
Begin
  Randomize;

  rndInt        := 0;
  maxRange      := Length(FPDictionary);
  fArrRndDict   := TStringList.Create;
  try
    i := 0;
    while i < maxRange do
    Begin

      rndInt := RandomRange(1, MAX_INT_RANGE);
      rndStr := RandomRange(0, maxRange);

      strValue := FPDictionary[rndStr];
      if trim(strValue) = '' then  continue;
      fArrRndDict.add( Format('%d.%s', [rndInt, strValue]));
      inc(i);
    End;
    SaveToFile();
  finally
    fArrRndDict.Free;
  end;
End;


Procedure TThGenerator.SaveToFile();                                            // SaveToFile
var
  fs          : TFileStream;
begin
  fs :=  TFileStream.Create(fFilePath, fmOpenWrite or fmShareDenyNone);
  try
    fs.Seek( 0, soFromEnd );

    fArrRndDict.SaveToStream(fs);
    fFsCurSize := fs.Size;
  finally
    fs.Destroy;
  end;
end;


Procedure TThGenerator.ShowProgress;                                            // ShowProgress
Begin
  fMain.pb_Main.Position := fPbCurPos;
  fMain.l_PbInfo.caption := fMes;
End;



function TThGenerator.GetStartFileSize( FileName: string;
                                        Overwriting : Boolean = true): Int64;   // GetStartFileSize
var
  FS: TFilestream;
begin
  Result := 0;
  try
    if Overwriting then
      FS := TFilestream.Create(Filename, fmCreate or fmShareDenyRead)
    else
      FS := TFilestream.Create(Filename, fmOpenRead or fmShareDenyRead);
  except
    Result := -1;
  end;
  if ( Result <> -1 ) and ( not Overwriting ) then
    Result := FS.Size;
  FS.Free;
end;

function TThGenerator.MakeMemSize(Size: Int64): String;                         // MakeMemSize
const
  kb = 1024;
  mb = kb*kb;
  gb = mb*kb;
begin
  case Size of
    0 ..kb-1: Result:=IntToStr(size)+' b';
    kb..mb-1: Result:=Format('%.2f Kb',[Size/kb]);
    mb..gb-1: Result:=Format('%.2f Mb',[Size/mb]);
  else
    Result:=Format('%.2f Gb',[Size/gb]);
  end;
end;

//+++++++++++++++++++++++++++ End TThGenerator +++++++++++++++++++++++++++++++++




procedure TfMain.tb_FileSizeChange(Sender: TObject);
begin
  try
    l_FileSize.Caption := FormatFloat('#,###,###.### Mb', tb_FileSize.Position);
    l_PbInfo.Caption   := l_FileSize.Caption;
    //pb_Main.Position   := tb_FileSize.Position;
  except
  end;
end;

// Preparation of the generation dictionary
Procedure TfMain.DictionaryPrepare();                                           // DictionaryPrepare
var
  dictMaxSize, i   : Integer;
Begin
  dictMaxSize := m_Dictionary.lines.Count;

  SetLength( Dictionary, dictMaxSize );

  for i:=0 to dictMaxSize -1 do
  Begin
    Dictionary[i] := m_Dictionary.lines.Strings[i] ;
  End;
  m_Dictionary.clear;
End;




procedure TfMain.FormClose(Sender: TObject; var Action: TCloseAction);          // FormClose
Begin
  if Assigned(thGen) then
  Begin
    // Signals the thread to end.
    thGen.Terminate;
    sleep(500);
    application.ProcessMessages;
  End;

end;

procedure TfMain.FormCreate(Sender: TObject);                                   // FormCreate

begin
  // Preparing a dictionary
  self.DictionaryPrepare();

  // Dimensions of the form when resize
  with Constraints do
  Begin
        MaxHeight := 140;
        MinHeight := 140;
        MinWidth  := 550;
  End;

  // ProgressBar
  pb_Main := TProgressBar.Create(sb_Main);
  with pb_Main do
  begin
    Parent      := sb_Main;
    Position    := 0;
    Top         := 2;
    Left        := 1;
    Max         := Round(MAX_FILESIZE/(1024*1024));
    Height      := sb_Main.Height - Top;
    Width       := sb_Main.Panels[0].Width - Left;
    visible     := true;
    Smooth      := true;
  end;

  // The inscription on the ProgressBar
  l_PbInfo := TLabel.Create(pb_Main);
  with l_PbInfo do
  Begin
    Parent      := pb_Main;
    Align       := alClient;
    Alignment   := taCenter;
    Font.Size   := 9;
    Font.Color  := clBlack;
    visible     := true;
    transparent := true;
  End;

  GetDir(0, FilePath);
  FilePath  := FilePath + '\' + FILE_NAME;

  // At the first launch, when there is no file yet, we do not show the button
  if FileExists(FilePath) then
  Begin
    chb_OwerWriting.visible := true;
  End;

end;

procedure TfMain.FormShow(Sender: TObject);                                     // FormShow
var
  freq,
  minPB,
  maxPb
         : integer;
begin
  // Adjust the scale
  freq  := Round ( ( MAX_FILESIZE/(1024*1024) - MIN_FILESIZE/(1024*1024) ) / 20 );
  minPB := Round( MIN_FILESIZE/(1024*1024) );
  maxPb := Round( MAX_FILESIZE/(1024*1024) );

  tb_FileSize.Frequency := freq;
  tb_FileSize.Min       := minPB;
  tb_FileSize.Max       := maxPb;
end;

procedure TfMain.FormResize(Sender: TObject);
begin
  if Assigned(pb_Main) then
  Begin
    sb_Main.Panels[0].Width := fMain.Width;
    pb_Main.Width           := sb_Main.Panels[0].Width - (pb_Main.Left+35);
  End;
end;

end.


