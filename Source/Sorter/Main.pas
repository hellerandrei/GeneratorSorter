unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Menus, ComCtrls, StdCtrls, ExtCtrls,

  syncobjs
  ;


const WM_MY_SORT_INFO = WM_USER + 1;

type

  ArrNoSort        = Array of integer;

//................................ TThIntArrSorter .............................

  TThIntArrSorter = class(TThread)
  private
    procedure QuickSort( var a: array of integer; min, max: Integer);
  public
    AIntArr : ArrNoSort;
  protected
    procedure Execute; override;
  end;
//..............................................................................



//................................ TThSorter ...................................

  TThSorter = class(TThread)
  private
    fMes,                                                                       // Message for the progress bar
    fInFilePath,                                                                // Source file
    fOutFilePath                                                                // The resulting file
                 : String;

    fPbCurPos, fPbOldPos                                                        // Variables for progresbar
                 : Int64;

    fMultiTh     : Boolean;                                                     // Multithreaded or sequential, time difference

    fArrRndDict  : TStringList;                                                 // Container for generated data



    function GetFileSize( FileName: string): Int64;

    Function CreateMatchArr() : boolean;
    Function Sorting(  ) : boolean;

    Procedure BinToAscii(const Bin: array of Byte; FrStart, FrEnd : Integer; var Str, Number : AnsiString);
    Procedure SaveToTxt( SortArr  : Array of Integer; StrName : String );
  public

    property AInFilePath   : String   write fInFilePath;
    property AOutFilePath  : String   write fOutFilePath;
    property AMultiTh      : Boolean  write fMultiTh;

    Procedure ShowProgress;                                                     // Synchronization function with the main window interface

    constructor Create();
    destructor Destroy; override ;
  protected
    procedure Execute; override;
  end;
//..............................................................................



  TfMain = class(TForm)
    od_InputFile: TOpenDialog;
    sb_Main: TStatusBar;
    Panel1: TPanel;
    l_FilePath: TLabel;
    Panel2: TPanel;
    b_FindFile: TButton;
    cb_MultiThread: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure b_FindFileClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    procedure WMOnWM_MYINFO(var msg: TMessage); message WM_MY_SORT_INFO;        // Processing messages from streams
  public
    workDir,
    inFilePath                                                                  // Source file
                   : String;

    pb_Main        : TProgressBar;
    l_PbInfo       : TLabel;
  end;

const
  INPUT_FILENAME  = 'result.txt';
  OUTPUT_FILENAME = 'sorted.txt';

var
  fMain               : TfMain;
  thSort              : TThSorter;
  CS                  : TCriticalSection;

  GArrMatching        : Array [ 0..500 ] of String;
  ArrZipTable         : array [ 0..500 ] of ArrNoSort;
  GWorkerCnt                                                                    // Counter of running threads
                      : Integer;

implementation

{$R *.dfm}



//------------------------------ TThIntArrSorter -------------------------------

Procedure TThIntArrSorter.Execute;                                              // Execute
Begin
  try
    // Sorting the array
    QuickSort(AIntArr, 0, length(AIntArr)-1);

  finally
    // Sorting is complete
    CS.Enter;
    try
      GWorkerCnt := GWorkerCnt - 1;
    finally
      CS.Leave;
    end;
  end;
End;

// Sorting an Integer array
procedure TThIntArrSorter.QuickSort( var a: array of integer; min, max: Integer);
Var
  i,j,
  mid,
  tmp
          : integer;
Begin
  if min < max then
  begin
    mid :=a [min];
    i := min-1;
    j := max+1;
    while i<j do
    begin
      repeat
        i:=i+1;
      until a[i]>=mid;

      repeat
        j := j - 1;
      until a[j] <= mid;

      if i < j then
      begin
        tmp:=a[i];
        a[i]:=a[j];
        a[j]:=tmp;
      end;
    end;

    QuickSort(a, min, j);
    QuickSort(a, j+1, max);
  end;
end;

//------------------------------ End TThIntArrSorter -------------------------------







procedure TfMain.WMOnWM_MYINFO(var msg: TMessage);                              // Message handler from the stream
var
  msgType,
  msgVal
                  : Integer;
  I: Integer;
begin
  msgType := msg.wParam;
  msgVal  := msg.lParam;

  case msgType of

    1: // The option of moving the progres bar
       Begin
         // PbShowMessage(msgVal, '');
       End;

    2: // Information received from the ThSort stream
       Begin
         case msgVal of

           1..2 : // Completed or interrupted without an accident
                 Begin
                   fMain.b_FindFile.Enabled      := true;
                   fMain.cb_MultiThread.Enabled  := true;
                   fMain.b_FindFile.Caption      := 'Sort';

                 End;

           3 :   // The thread is destroyed in the destructor
                 Begin
                   thSort := nil;
                   for I := 0 to Length(ArrZipTable)-1 do
                   Begin
                     SetLength(ArrZipTable[i],0);
                   End;
                 End;

           4 :   // One of the functions returned an error
                 Begin
                   fMain.b_FindFile.Enabled      := true;
                   fMain.cb_MultiThread.Enabled  := true;
                   fMain.b_FindFile.Caption      := 'Sort';
                 End;
           5 :   Begin

                 End;

         end;

       End;

    // TThIntArrSorter
    3: Begin
         case msgVal of
           1: Begin

              End;
         end;
       End;
  end;

End;




//++++++++++++++++++++++++++  TThSorter  ++++++++++++++++++++++++++++++++++++

Procedure TThSorter.Execute;                                                    // Execute
Begin
  try
    // Create a file if it is not there (checks are needed)
    GetFileSize(fOutFilePath);

    if CreateMatchArr() then
    Begin
      if Sorting () then
      Begin
        // Message - Operation completed
        fPbCurPos := 0;
        fMes      := 'The operation is completed! - The file is located ->' + fOutFilePath;
        Synchronize(ShowProgress);
        PostMessage( fMain.Handle, WM_MY_SORT_INFO, 2, 1 );
        exit;
      End;
    End;

  except
    // Message - Operation not completed
    fPbCurPos := 0;
    fMes      := 'Operation failed!';
    Synchronize(ShowProgress);
    PostMessage( fMain.Handle, WM_MY_SORT_INFO, 2, 4 );
  end;
End;


// Saving to a file
Procedure TThSorter.SaveToTxt( SortArr  : Array of Integer; StrName : String ); // SaveToTxt
var
  i, j : Integer;
  sl   : TStringList;
  fs   : TFileStream;
Begin
   sl := TStringList.Create;
   try
     for i := 0 to Length(SortArr)-1 do
     Begin
       sl.Add( IntToStr( SortArr[i] ) + '.' + StrName );
     End;

     fs :=  TFileStream.Create( fOutFilePath, fmOpenReadWrite );
     try
        fs.Seek( 0, soFromEnd );
        sl.SaveToStream(fs);
     finally
       fs.Destroy;
     end;

   finally
     sl.Free;
   end;

End;

// Custom sorting of strings
function CompareStringsAscending( List: TStringList;
                                  Index1, Index2: Integer):Integer;
  var
    str1,
    str2,
    fullStr1,
    fullStr2
            : String;

    posDot1,
    posDot2
            : Integer;
  begin
     fullStr1 := List[Index1];
     fullStr2 := List[Index2];

     Result :=  CompareText(fullStr1, fullStr2);
  end;


function TThSorter.Sorting( ) : boolean;                                        // Sorting
  // Search in the array of matches by name
  function FindIdxFromArrMatchByName( ArrMatching : Array of String;
                                        Str : String ) : Integer;
    var
      I: Integer;
    Begin
      result := -1;
      for I := 0 to length(ArrMatching) -1 do
      Begin
        if ArrMatching[i] = Str then
        Begin
          result := i;
        End;
      End;
    End;

    // Sorting an array
    Procedure SortIntArray ( var NotSortArr : Array of Integer );
    var
      i, j,
      tmpVal
                 : Integer;
    Begin
      i := 0;
      while i <= Length(NotSortArr)-1 do
      Begin
        j := i + 1;
        while j <= Length(NotSortArr)-1 do
        Begin
          if NotSortArr[i] > NotSortArr[j] then
          Begin
             tmpVal           := NotSortArr[i];
             NotSortArr[i]    := NotSortArr[j];
             NotSortArr[j]    := tmpVal;
          End;
          inc(j);
        End;
        inc(i);
      End;
    End;

var
  i, j, k,
  fndIdx
               : Integer;
  sl           : TStringList;
  ThSortWorker : Array of TThIntArrSorter ;
  tempIntRow   : Array [ 0..500 ] of ArrNoSort;
Begin
  Result := false;
  sl := TStringList.Create;
  try

    for i := 0 to Length(GArrMatching)-1 do
    Begin
      if GArrMatching[i] <> '' then
        sl.Add(GArrMatching[i]);
    End;

    // Sorting string data
    sl.CustomSort(CompareStringsAscending);

    for i := 0 to sl.Count-1 do
    Begin
      if length(sl.Strings[i]) < 1 then
        continue;

      If Terminated then
      Begin
        fPbCurPos := 0;
        fMes := 'Operation aborted!';
        Synchronize(ShowProgress);
        // Message - Operation aborted
        PostMessage( fMain.Handle, WM_MY_SORT_INFO, 2, 2 );
        exit;
      End;

      // Drawing progres
      fPbCurPos := Round(i * 100 / (sl.Count-1));
      if fPbCurPos <>  fPbOldPos then
      Begin
        fPbOldPos := fPbCurPos;
        fMes := 'Sorting of read lowercase data: ' + IntToStr(fPbCurPos)+'%';
        Synchronize(ShowProgress);
      End;

      // We find an element in the matching array, by name
      fndIdx := FindIdxFromArrMatchByName( GArrMatching, sl.Strings[i] );
      if fndIdx >= 0 then
      Begin
        // Filling in a temporary array
        setLength( TempIntRow[i], length(ArrZipTable[fndIdx]) );
        for j := 0 to length(ArrZipTable[fndIdx]) -1 do
        begin
          TempIntRow[i][j] := ArrZipTable[fndIdx][j];
        end;

        // If done sequentially, without multithreading
        if not fMultiTh then
        Begin

          // Sorting the Number part
          SortIntArray( TempIntRow[i] );

          // Save to a file
          SaveToTxt( TempIntRow[i], sl.Strings[i] );
        End;
      End;
    End;

    // Multithreaded version
    if fMultiTh then
    Begin
      for i:=0 to Length(TempIntRow) -1 do
      Begin
        SetLength( ArrZipTable[i], Length(TempIntRow[i]) );
        for j:=0 to Length(TempIntRow[i]) -1 do
        Begin
          ArrZipTable[i][j] := TempIntRow[i][j];
        end;
      End;

      // We perform sorting in different threads
      SetLength(ThSortWorker, length(ArrZipTable));

      for i := 0 to length(ArrZipTable)-1 do
      Begin
        ThSortWorker[i]            := TThIntArrSorter.Create(true);
        ThSortWorker[i].AIntArr    := ArrZipTable[i];
        ThSortWorker[i].priority   := tpLowest;

        // Drawing progres
        fPbCurPos := Round(i * 100 / (length(ArrZipTable)));
        if fPbCurPos <>  fPbOldPos then
        Begin
          fPbOldPos := fPbCurPos;
          fMes := 'Starting the sorting of numbers: ' + IntToStr(fPbCurPos)+'%';
          Synchronize(ShowProgress);
        End;

        // Changing the worker counter variable is thread-safe
        CS.Enter;
        try
          GWorkerCnt  := GWorkerCnt + 1;
        finally
          CS.Leave;
        end;

        ThSortWorker[i].Resume;
      End;

      // Timer for checking, shutting down threads
      while True do
      Begin
        sleep(1000);
        CS.Enter;
        try
          if GWorkerCnt = 0 then
            break;
        finally
          CS.Leave;
        end;
      end;

      for i := 0 to sl.Count-1 do
      Begin

        // Drawing progres
        fPbCurPos := Round(i * 100 / ( sl.Count ));
        if fPbCurPos <>  fPbOldPos then
        Begin
          fPbOldPos := fPbCurPos;
          fMes := 'Recording the result: ' + IntToStr(fPbCurPos)+'%';
          Synchronize(ShowProgress);
        End;

        // Save to a file
        SaveToTxt( ArrZipTable[i], sl.Strings[i] );
      End;

    End;

    Result := true;

  finally
    sl.Free;
  end;
End;



function TThSorter.CreateMatchArr() : boolean;                                  // CreateMatchArr()
var
  i, j,
  found13,
  readed,
  arrMachInx,
  fndPosit
              : Integer;

  readStart,
  readEnd,
  maxFsSize
              : Int64;

  FS          : TFilestream;
  sl          : TStringList;
  buf         : array [0..1024] of byte;
  str, num    : AnsiString;

  // Uniqueness of the element
  function CheckIsArrElUnic( Str : String; Arr : Array of String ): integer;
  var
    i, j : Integer;
  Begin
    result := -1;
    if Str = '' then
      exit;

    for i := 0 to length(Arr)-1 do
    Begin
      if Arr[i] = Str then
      Begin
        result := i;
        break;
      End;
      result := -2;
    End;
  End;

begin
  Result := false;
  readed := 0;

  FS := TFilestream.Create( fInFilePath, fmOpenRead or fmShareDenyRead);
  try
    readStart    := 0;
    readEnd      := 0;
    arrMachInx   := 0;
    maxFsSize    := fs.Size;

    // We read from the file in portions
    while readEnd < maxFsSize do
    Begin

      // Cancellation from the user
      If Terminated then
      Begin
        fPbCurPos := 0;
        fMes := 'Operation aborted!';
        Synchronize(ShowProgress);
        // Message to the main form - Operation aborted
        PostMessage( fMain.Handle, WM_MY_SORT_INFO, 2, 2 );
        exit;
      End;

      if readEnd > readStart then
        readStart := readEnd;

      // Drawing progress
      fPbCurPos := Round(readEnd * 100 / maxFsSize);
      if fPbCurPos <>  fPbOldPos then
      Begin
        fPbOldPos := fPbCurPos;
        fMes := 'Analysis of the file structure: ' + IntToStr(fPbCurPos)+'%';
        Synchronize(ShowProgress);
      End;

      fs.Seek(readStart, soBeginning);
      readed := fs.Read( buf, length(buf)-1 );

      // We are looking for the end of the text block
      if readed > 0 then
      Begin
        if readed < 2 then
        Begin
          Result := true;
          exit;
        End;

        found13     := -1;
        SetLength(str , 0);

        // We fill the array of correspondences with the found words
        for j := 0 to readed do
        begin
          // Working with strings
          if buf[j] = ord(#13) then
          Begin
            bintoAscii( buf, found13+1, j-1, str, num);

            // Checking the uniqueness
            fndPosit := CheckIsArrElUnic(str, GArrMatching);
            case fndPosit of
              // Mistake
              -1 : Begin

                   End;
              // A unique string, will be the first element in the fArrZipTable
              -2 : Begin
                    GArrMatching[arrMachInx] := str;
                    SetLength( ArrZipTable[arrMachInx], 1 );
                    ArrZipTable[arrMachInx][0] := StrToInt( copy(num, 1, pos('.',num)-1 ));
                    inc(arrMachInx);
                   End
              else
                  // Not a unique string, we add it to the dynamic array in fArrZipTable
                  Begin
                    SetLength( ArrZipTable[fndPosit], length(ArrZipTable[fndPosit])+1 );
                    ArrZipTable[fndPosit][length(ArrZipTable[fndPosit])-1] := StrToInt( copy(num, 1, pos('.',num)-1 ));
                  End;
            end;
            found13 := j+1;
          End;
        end;
      End;
      readEnd := readEnd + found13;
    End;

  finally
    FS.Free;
  end;

End;





constructor TThSorter.Create();
Begin
  Randomize;
  Inherited Create(True) ;
  FreeOnTerminate := true;
End;

destructor TThSorter.Destroy;
Begin
  // Message - Can be released, the thread has finished its journey
  PostMessage( fMain.Handle, WM_MY_SORT_INFO, 2, 3 );
End;





Procedure TThSorter.ShowProgress;                                               // ShowProgress - Working with the interface of the main form
Begin
  fMain.pb_Main.Position := fPbCurPos;
  fMain.l_PbInfo.caption := fMes;
End;


function TThSorter.GetFileSize( FileName: string): Int64;                       // GetStartFileSize
var
  FS: TFilestream;
begin
  Result := 0;
  FS := TFilestream.Create(Filename, fmCreate or fmShareDenyRead);
  if Result <> -1  then
    Result := FS.Size;
  FS.Free;
end;

Procedure TThSorter.BinToAscii( const Bin: array of Byte;                       // BinToAscii
                                FrStart, FrEnd : Integer;
                                var Str, Number : AnsiString);
var
  i, j, n   : integer;
  dotFound  : boolean;
begin
  j         := 1;
  n         := 1;
  dotFound  := false;

  Str       := '';
  Number    := '';

  for i := FrStart to FrEnd do
  Begin
    if ( bin[i] = ord(#13) ) or  ( bin[i] = ord(#10) ) then
      continue;

    if dotFound then
    Begin

      str[j] := AnsiChar(bin[i]);
      inc(j);
    End
    else
    Begin
      SetLength(Number, n);
      Number[n] := AnsiChar(bin[i]);
      inc(n);
    End;

    if bin[i] = ord('.') then
    Begin
      SetLength(str, FrEnd - i);
      dotFound := True;
    End;
  End;

end;

//++++++++++++++++++++++++++++++ End TThSorter +++++++++++++++++++++++++++++++++











procedure TfMain.b_FindFileClick(Sender: TObject);
begin
 if fMain.b_FindFile.Caption = 'Choose' then
 begin
   od_InputFile.InitialDir := workDir;
   od_InputFile.Filter     := 'Text files|*.txt';

   if od_InputFile.Execute then
   Begin
     inFilePath                    := od_InputFile.FileName;
     fMain.l_FilePath.caption      := 'File: ' + inFilePath;

     fMain.b_FindFile.Caption      := 'Sort';
     fMain.cb_MultiThread.visible  := true;
   End;
 end

 else

 if fMain.b_FindFile.Caption = 'Sort' then
 begin
    // Unblocks at the end of the stream - WMOnWM_MYINFO
    fMain.b_FindFile.Caption      := 'Abort';
    fMain.cb_MultiThread.Enabled  := false;
    fMain.pb_Main.Visible         := true;

    if not Assigned(thSort) then
    Begin
      thSort    := TThSorter.Create();
      try
        // Passing parameters to the stream
        thSort.AInFilePath  := inFilePath;
        thSort.AOutFilePath := workDir + '\sorted.txt';

        if cb_MultiThread.Checked then
          thSort.AMultiTh := true;

      finally
        thSort.Resume;
      end;
    end;

  end

 else

 if fMain.b_FindFile.Caption = 'Abort' then
  Begin
    if Assigned(thSort) then
    Begin
      thSort.Terminate;
    End;
  end;

end;





procedure TfMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  CS.Free;

  if Assigned(thSort) then
  Begin
    // Signals the thread to end.
    thSort.Terminate;
    sleep(500);
    application.ProcessMessages;
  End;
end;


procedure TfMain.FormCreate(Sender: TObject);                                   // FormCreate
begin
  CS         := TCriticalSection.Create;
  GWorkerCnt := 0;
  // Dimensions of the form when resize
  with Constraints do
  Begin
        MaxHeight := 160;
        MinHeight := 160;
        MinWidth  := 550;
  End;


  // Progressbar
  pb_Main := TProgressBar.Create(sb_Main);
  with pb_Main do
  begin
    Parent      := sb_Main;
    Position    := 0;
    Top         := 0;
    Left        := 1;
    Max         := 100;
    Height      := sb_Main.Height - Top;
    Width       := sb_Main.Panels[0].Width;
    visible     := false;
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
    top         := 3;
    Font.Color  := clBlack;
    visible     := true;
    transparent := true;
  End;

  GetDir( 0, workDir);
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


