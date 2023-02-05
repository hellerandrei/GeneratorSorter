unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Menus, ComCtrls, StdCtrls, ExtCtrls;


const WM_MY_SORT_INFO = WM_USER + 1;

type

  //DictArr    = Array of String;
  ZipTable   = Array [0..500] of array of Integer;
  ArrNoSort  = Array of integer;

//................................ TThIntArrSorter ...................................

  TThIntArrSorter = class(TThread)
  private

    fIdx       : Integer;

  public
    fNoSortArr : ZipTable;
    // property ANoSortArr   : ZipTable   write fNoSortArr;
    property AIdx   : Integer   write fIdx;
  protected
    procedure Execute; override;
  end;




//................................ TThSorter ...................................

  TThSorter = class(TThread)
  private
    fMes,
    fInFilePath,
    fOutFilePath
                 : String;

    fPbCurPos, fPbOldPos,                                                       // Переменная для прогресбара
    fFsCurSize,                                                                 // Текущий размер файла
    fFsMaxSize                                                                  // Максимальный размер файла
                 : Int64;

    fMultiTh     : Boolean;                                                     //

    //fPDictionary : DictArr;                                                     // Словарь, только чтение

    fArrRndDict  : TStringList;                                                 // Контейнер для сгенерированных данных

    fArrZipTable  : ZipTable;

    function GetStartFileSize( FileName: string): Int64;
    function MakeMemSize(Size: Int64): String;
    function GetFileSize( FileName: string): Int64;

    Function CreateMatchArr() : boolean;
    Function Sorting( ArrZipTable  : ZipTable ) : boolean;

    Procedure BinToAscii(const Bin: array of Byte; FrStart, FrEnd : Integer; var Str, Number : AnsiString);
    Procedure SaveToTxt( SortArr  : Array of Integer; StrName : String );
  public
    property AInFilePath   : String   write fInFilePath;                        // Передача параметров в поток
    property AOutFilePath  : String   write fOutFilePath;
    //property APDictionary  : DictArr  write FPDictionary; 
    property AMultiTh      : Boolean  write fMultiTh;

    Procedure ShowProgress;                                                     // Функция синхронизации с интерфейсом главного окна

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
    procedure FormCreate(Sender: TObject);
    procedure b_FindFileClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure l_FilePathClick(Sender: TObject);
  private
    procedure WMOnWM_MYINFO(var msg: TMessage); message WM_MY_SORT_INFO;              // Обработка сообщений из потока
  public
    workDir,
    inFilePath
                   : String;

    pb_Main        : TProgressBar;
    l_PbInfo       : TLabel;

    Dictionary     : DictArr;
    Function SortInt(  ) : boolean;
  end;

const
  INPUT_FILENAME  = 'result.txt';
  OUTPUT_FILENAME = 'sorted.txt';

var
  fMain               : TfMain;
  GArrMatching        : Array [0..500] of  String;
  thSort              : TThSorter;
  GSortedStrZipTable  : ZipTable;

implementation

{$R *.dfm}


Procedure TThIntArrSorter.Execute;                                                    // Execute
var
  i, j,
  tmpVal
             : Integer;
Begin
  i := 0;
  while i <= Length(fNoSortArr[fIdx])-1 do
  Begin
    j := i + 1;
    while j <= Length(fNoSortArr[fIdx])-1 do
    Begin
      if fNoSortArr[fIdx][i] > fNoSortArr[fIdx][j] then
      Begin
         tmpVal                 := fNoSortArr[fIdx][i];
         fNoSortArr[fIdx][i]    := fNoSortArr[fIdx][j];
         fNoSortArr[fIdx][j]    := tmpVal;
      End;
      inc(j);
    End;
    inc(i);
  End;

End;

{constructor TThIntArrSorter.Create();
Begin
  Randomize;
  Inherited Create(True) ;
  FreeOnTerminate := true;
End;

destructor TThIntArrSorter.Destroy;
Begin

End;    }


procedure TfMain.WMOnWM_MYINFO(var msg: TMessage);                              // Обработчик сообщений из потока
var
  msgType,
  msgVal
                  : Integer;
begin
  msgType := msg.wParam;
  msgVal  := msg.lParam;

  case msgType of

    1: // Вариант передвижения прогрес бара
       Begin
         // PbShowMessage(msgVal, '');
       End;

    2: // Информация, полученная от потока
       Begin
         case msgVal of

           1..2 : // Завершился или прервался без аварии
                 Begin
                   fMain.b_FindFile.Enabled      := true;
                   fMain.b_FindFile.Caption      := 'Сортировать';

                 End;

           3 :   // Поток разрушен в деструкторе
                 Begin
                   thSort := nil;
                 End;

           4 :   // Одна из функций вернула ошибку
                 Begin
                   fMain.b_FindFile.Enabled      := true;
                   fMain.b_FindFile.Caption      := 'Сортировать';
                 End;

           5 :   Begin
                  SortInt(  );
                 End;
         end;

       End;
  end;

End;



Function TfMain.SortInt(  ) : boolean;
var
  I: Integer;
  ThSortWorker : array of TThIntArrSorter;
begin
  Result := false;

  SetLength(ThSortWorker, length(GSortedStrZipTable));

  for I := 0 to length(GSortedStrZipTable)-1 do
  Begin
    ThSortWorker[i] := TThIntArrSorter.Create(true);
    ThSortWorker[i].fNoSortArr := GSortedStrZipTable;
    ThSortWorker[i].priority   := tpLowest;
    ThSortWorker[i].fIdx       := i;
    ThSortWorker[i].Resume;
  End;

end;


//++++++++++++++++++++++++++  TThSorter  ++++++++++++++++++++++++++++++++++++

Procedure TThSorter.Execute;                                                    // Execute
Begin
  try
    GetFileSize(fOutFilePath);

    if CreateMatchArr() then
    Begin
      if Sorting (fArrZipTable) then
      Begin
        // Сообщение - Операция завершена
        fPbCurPos := 0;
        fMes      := 'Операция выполнена! - Файл находится -> ' + fOutFilePath;
        Synchronize(ShowProgress);
        PostMessage( fMain.Handle, WM_MY_SORT_INFO, 2, 1 );
        exit;
      End;
    End;

  except
    // Сообщение - Операция не завершена
    fPbCurPos := 0;
    fMes      := 'Операция не выполнена!';
    Synchronize(ShowProgress);
    PostMessage( fMain.Handle, WM_MY_SORT_INFO, 2, 4 );
  end;


End;


function CompareStringsAscending(List: TStringList; Index1, Index2: Integer):Integer;
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






Procedure TThSorter.SaveToTxt( SortArr  : Array of Integer; StrName : String );
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







function TThSorter.Sorting( ArrZipTable  : ZipTable ) : boolean;                // Sorting
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
//  tmpArrInt    : array of Integer;

Begin
  Result := false;
  sl := TStringList.Create;
  try

    for i := 0 to Length(GArrMatching)-1 do
    Begin
      if GArrMatching[i] <> '' then
        sl.Add(GArrMatching[i]);
    End;

    sl.CustomSort(CompareStringsAscending);
//    SetLength( ThSortWorker, Length(GArrMatching) );



    for i := 0 to sl.Count-1 do
    Begin
      if length(sl.Strings[i]) < 1 then
        continue;

      If Terminated then
      Begin
        fPbCurPos := 0;
        fMes := 'Операция прервана!';
        Synchronize(ShowProgress);
        // Сообщение - Операция прервана
        PostMessage( fMain.Handle, WM_MY_SORT_INFO, 2, 2 );
        exit;
      End;

      fPbCurPos := Round(i * 100 / (sl.Count-1));
      if fPbCurPos <>  fPbOldPos then
      Begin
        fPbOldPos := fPbCurPos;
        fMes := 'Сортировка прочитанных данных: ' + IntToStr(fPbCurPos)+'%';
        Synchronize(ShowProgress);
      End;

      fndIdx := FindIdxFromArrMatchByName( GArrMatching, sl.Strings[i] );
      if fndIdx >= 0 then
      Begin

        // Заполняем временный массив
        setLength( GSortedStrZipTable[i], length(ArrZipTable[fndIdx]) );
        for j := 0 to length(ArrZipTable[fndIdx]) -1 do
        begin
          GSortedStrZipTable[i][j] := ArrZipTable[fndIdx][j];
        end;

        if not fMultiTh then
        Begin
          SortIntArray( GSortedStrZipTable[i] );
          SaveToTxt( GSortedStrZipTable[i], sl.Strings[i] );
        End;

      End;
    End;

    if fMultiTh then
    Begin
      PostMessage( fMain.Handle, WM_MY_SORT_INFO, 2, 5 );
    End;

    Result := true;

  finally
    sl.Free;
  end;
End;



function TThSorter.CreateMatchArr() : boolean;
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

    while readEnd < maxFsSize do
    Begin
      If Terminated then
      Begin
        fPbCurPos := 0;
        fMes := 'Операция прервана!';
        Synchronize(ShowProgress);
        // Сообщение - Операция прервана
        PostMessage( fMain.Handle, WM_MY_SORT_INFO, 2, 2 );
        exit;
      End;


      if readEnd > readStart then
        readStart := readEnd;


      fPbCurPos := Round(readEnd * 100 / maxFsSize);
      if fPbCurPos <>  fPbOldPos then
      Begin
        fPbOldPos := fPbCurPos;
        fMes := 'Анализ структуры файала: ' + IntToStr(fPbCurPos)+'%';
        Synchronize(ShowProgress);
      End;

      fs.Seek(readStart, soBeginning);
      readed := fs.Read( buf, length(buf)-1 );

      // Ищем окончание текстового блока с учетом перевода каретки
      if readed > 0 then
      Begin
        if readed < 2 then
        Begin
          Result := true;
          exit;
        End;

        found13     := -1;
        SetLength(str , 0);

        for j := 0 to readed do
        begin
          if buf[j] = ord(#13) then
          Begin
            bintoAscii( buf, found13+1, j-1, str, num);
            fndPosit := CheckIsArrElUnic(str, GArrMatching);
            case fndPosit of
            -1 : Begin

                 End;
            -2 : Begin
                  GArrMatching[arrMachInx] := str;
                  SetLength( fArrZipTable[arrMachInx], 1 );
                  fArrZipTable[arrMachInx][0] := StrToInt( copy(num, 1, pos('.',num)-1 ));
                  inc(arrMachInx);
                 End
            else
                Begin
                  SetLength( fArrZipTable[fndPosit], length(fArrZipTable[fndPosit])+1 );

                  fArrZipTable[fndPosit][length(fArrZipTable[fndPosit])-1] := StrToInt( copy(num, 1, pos('.',num)-1 ));
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

  // Сообщение - Можно освободить, поток закончил свой путь
  PostMessage( fMain.Handle, WM_MY_SORT_INFO, 2, 3 );
End;





Procedure TThSorter.ShowProgress;                                               // ShowProgress - Работа с интерфейсом главной формы
Begin
  fMain.pb_Main.Position := fPbCurPos;
  fMain.l_PbInfo.caption := fMes;
End;

Procedure TThSorter.BinToAscii(const Bin: array of Byte; FrStart, FrEnd : Integer; var Str, Number : AnsiString);
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

function TThSorter.GetStartFileSize( FileName: string): Int64;                  // GetStartFileSize - Определяем размер файла
var
  FS: TFilestream;
begin
  Result := 0;
  try
      FS := TFilestream.Create(Filename, fmOpenRead or fmShareDenyRead);
  except
    Result := -1;
  end;
  if Result <> -1  then
    Result := FS.Size;
  FS.Free;
end;

function TThSorter.MakeMemSize(Size: Int64): String;                            // MakeMemSize - Человекочитаемый формат размера файла
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



//++++++++++++++++++++++++++++++ End TThSorter +++++++++++++++++++++++++++++++++








procedure TfMain.b_FindFileClick(Sender: TObject);
begin
 if fMain.b_FindFile.Caption = 'Выбрать' then
 begin
   od_InputFile.InitialDir := workDir;
   od_InputFile.Filter     := 'Текстовые файлы|*.txt';

   if od_InputFile.Execute then
   Begin
     inFilePath               := od_InputFile.FileName;
     fMain.l_FilePath.caption := 'Файл: ' + inFilePath;

     // Проверяем есть ли наш формат внутри
     fMain.b_FindFile.Caption := 'Сортировать';
   End;
 end

 else

 if fMain.b_FindFile.Caption = 'Сортировать' then
 begin
    // Разблокируется при завершении потока - WMOnWM_MYINFO
    fMain.b_FindFile.Caption      := 'Прервать';
    fMain.pb_Main.Visible         := true;

    if not Assigned(thSort) then
    Begin
      thSort    := TThSorter.Create();
      try
        // Передаем параметры в поток
        thSort.AInFilePath  := inFilePath;
        thSort.AOutFilePath := workDir + '\sorted.txt';
        thSort.AMultiTh := true;

      finally
        thSort.Resume;
      end;
    end;

  end

 else

 if fMain.b_FindFile.Caption = 'Прервать' then
  Begin
    if Assigned(thSort) then
    Begin
      thSort.Terminate;
    End;
  end;

end;












procedure TfMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
if Assigned(thSort) then
  Begin
    // Сигнализируем потоку о завершении.
    thSort.Terminate;
    sleep(500);
    application.ProcessMessages;
  End;
end;

procedure TfMain.FormCreate(Sender: TObject);                                   // FormCreate
begin
  // Размеры формы при resize
  with Constraints do
  Begin
        MaxHeight := 140;
        MinHeight := 140;
        MinWidth  := 550;
  End;


  // Прогресбар
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

  // Надпись на Прогресбаре
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

procedure TfMain.l_FilePathClick(Sender: TObject);
begin
  beep();
end;

end.

//function CompareStringsAscending(List: TStringList; Index1, Index2: Integer):Integer;
//var
//  str1,
//  str2,
//  fullStr1,
//  fullStr2
//          : String;
//
//  posDot1,
//  posDot2
//          : Integer;
//begin
//   fullStr1 := List[Index1];
//   fullStr2 := List[Index2];
//
//   posDot1 := pos('.', fullStr1);
//   posDot2 := pos('.', fullStr2);
//
//   if ( posDot1 <> 0 ) and ( posDot2 <> 0 ) then
//   Begin
//     str1 := copy(fullStr1, posDot1+1, length(fullStr1)-posDot1+1);
//     str2 := copy(fullStr2, posDot2+1, length(fullStr2)-posDot2+1);
//
//     Result :=  CompareText(str1, str2);
//
//   End;
//
//end;
//
//function checkInt( S : string) : integer;
//var
//   errorPos, I : Integer;
//begin
//  Val(S, I, errorPos);
//  if errorPos = 0 then
//  result := i
//  else
//  result := -1;
//end;

//function CompareIntsAscending(List: TStringList; Index1, Index2: Integer):Integer;
//var
//  fullStr1,
//  fullStr2,
//  str1,
//  str2
//          : String;
//
//  posDot1,
//  posDot2,
//  d1,
//  d2
//          : Integer;
//begin
//   fullStr1 := List[Index1];
//   fullStr2 := List[Index2];
//
//   posDot1 := pos('.', fullStr1);
//   posDot2 := pos('.', fullStr2);
//
//
//   if ( posDot1 <> 0 ) and ( posDot2 <> 0 ) then
//   Begin
//     d1 := checkInt( copy(fullStr1, 1, posDot1-1) );
//     d2 := checkInt( copy(fullStr2, 1, posDot2-1) );
//
//     str1 := copy(fullStr1, posDot1+1, length(fullStr1)-posDot1+1);
//     str2 := copy(fullStr2, posDot2+1, length(fullStr2)-posDot2+1);
//
//     if ( d1 < d2 ) and ( str1 = str2 ) then
//       Result := -1
//     else if ( d1 > d2 ) and ( str1 = str2 ) then
//       Result := 1
//     else
//       Result := 0;
//   End;
//
//end;
//
//Procedure SortCompaireInt( List: TStringList; segmentStart, segmentEnd : Integer );
//var
//  i, j,
//  d1, d2,
//  posDot1,
//  posDot2
//            : Integer;
//
//  fullStr1,
//  fullStr2,
//  strTemp
//            : String;
//Begin
//  for I := segmentStart to segmentEnd do
//  begin
//    fullStr1 := List[i];
//    posDot1  := pos('.', fullStr1);
//    d1       := checkInt( copy(fullStr1, 1, posDot1-1) );
//
//    for j := i + 1 to segmentEnd do
//    Begin
//      fullStr1  := List[i];
//      posDot1   := pos('.', fullStr1);
//      d1        := checkInt( copy(fullStr1, 1, posDot1-1) );
//
//      fullStr2  := List[j];
//      posDot2   := pos('.', fullStr2);
//
//      d2 := checkInt( copy(fullStr2, 1, posDot2-1) );
//
//      if ( d1 > d2 ) then
//      Begin
//         strTemp   := List[i];
//         List[i]   := List[j];
//         List[j]   := strTemp;
//      End;
//    End;
//  end;
//
//
//
//End;
//
//Procedure TfMain.SortByInt( List: TStringList );
//var
//  i, j, k,
//  posDot1,
//  posDot2,
//  d1, d2,
//  segmentStart,
//  segmentEnd
//              : Integer;
//
//  fullStr1,
//  fullStr2,
//  str1,
//  str2,
//  strTemp
//              : String;
//Begin
//  segmentStart := 0;
//  for i := 0 to List.count-1 do
//  Begin
//    if i < segmentStart then
//      continue;
//    fullStr1 := List[i];
//    posDot1  := pos('.', fullStr1);
//    str1     := copy(fullStr1, posDot1+1, length(fullStr1)-posDot1+1);
//    d1       := checkInt( copy(fullStr1, 1, posDot1-1) );
//
//    for j := i+1 to List.count-1 do
//    Begin
//      fullStr2  := List[j];
//      posDot2   := pos('.', fullStr2);
//      str2      := copy(fullStr2, posDot2+1, length(fullStr2)-posDot2+1);
//
//      // Конец отсортированных значений
//      if ( str1 <> str2 ) or ( j = List.count-1 ) then
//      Begin
//        segmentEnd := j - 1;
//        if j = List.count-1 then
//           segmentEnd := List.count-1;
//        SortCompaireInt( List, segmentStart, segmentEnd );
//        segmentStart := segmentEnd + 1;
//
//        break;
//      End;
//    End;
//  End;
//End;



//Procedure TThSorter.SortArrZipByNumber( ArrZipTable  : ZipTable );
//var
//  I, j, k, tmpVal : Integer;
//Begin
//  for i := 0 to Length(ArrZipTable)-1 do
//  Begin
//    j := 0;
//    while j <= Length(ArrZipTable[i])-1 do
//    Begin
//      k := j + 1;
//      while k <= Length(ArrZipTable[i])-1 do
//      Begin
//        if ArrZipTable[i][j] > ArrZipTable[i][k] then
//        Begin
//           tmpVal               := ArrZipTable[i][j];
//           ArrZipTable[i][j]    := ArrZipTable[i][k];
//           ArrZipTable[i][k]    := tmpVal;
//        End;
//
//        inc(k);
//      End;
//      inc(j);
//    End;
//
//  End;
//
//End;







//function checkInt( S : string) : integer;
//var
//   errorPos, I : Integer;
//begin
//  Val(S, I, errorPos);
//  if errorPos = 0 then
//  result := i
//  else
//  result := -1;
//end;
