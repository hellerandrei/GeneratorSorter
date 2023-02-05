unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Menus, ComCtrls, StdCtrls, ExtCtrls,

  syncobjs
  ;


const WM_MY_SORT_INFO = WM_USER + 1;

type

  DictArr    = Array of String;
  ZipTable   = Array [0..500] of array of Integer;
  ArrNoSort  = Array of integer;

//................................ TThIntArrSorter .............................

  TThIntArrSorter = class(TThread)
  private
    fTempArr   : array of Integer;
    fIdx       : Integer;
    procedure QuickSort( var a: array of integer; min, max: Integer);
  public
    fNoSortArr : ZipTable;
    property AIdx   : Integer   write fIdx;
  protected
    procedure Execute; override;
  end;
//..............................................................................


//................................ TThSorter ...................................

  TThSorter = class(TThread)
  private
    fMes,                                                                       // Сообщение  для прогресбара
    fInFilePath,                                                                // Исходный файл
    fOutFilePath                                                                // Результирующий файл
                 : String;

    fPbCurPos, fPbOldPos                                                        // Переменные для прогресбара
                 : Int64;

    fMultiTh     : Boolean;                                                     // Многопоточно или последовательно, разница во времени

    fArrRndDict  : TStringList;                                                 // Контейнер для сгенерированных данных

    fArrZipTable  : ZipTable;

    function GetFileSize( FileName: string): Int64;

    Function CreateMatchArr() : boolean;
    Function Sorting( ArrZipTable  : ZipTable ) : boolean;

    Procedure BinToAscii(const Bin: array of Byte; FrStart, FrEnd : Integer; var Str, Number : AnsiString);
    Procedure SaveToTxt( SortArr  : Array of Integer; StrName : String );
  public

    property AInFilePath   : String   write fInFilePath;                        // Передача параметров в поток
    property AOutFilePath  : String   write fOutFilePath;
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
    cb_MultiThread: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure b_FindFileClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    procedure WMOnWM_MYINFO(var msg: TMessage); message WM_MY_SORT_INFO;        // Обработка сообщений из потоков
  public
    workDir,
    inFilePath                                                                  // Исходный файл
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

  GArrMatching        : Array [0..500] of  String;
  GSortedStrZipTable  : ZipTable;
  GWorkerCnt                                                                  // Счетчик работающих потоков
                      : Integer;

implementation

{$R *.dfm}



//------------------------------ TThIntArrSorter -------------------------------

Procedure TThIntArrSorter.Execute;                                              // Execute
var
  i, j,
  tmpVal
             : Integer;
Begin
  try
    setLength(fTempArr, Length(fNoSortArr[fIdx]));
    for i := 0 to Length(fNoSortArr[fIdx]) -1 do
    Begin
      fTempArr[i] := fNoSortArr[fIdx][i];
    End;

    // Сортируем массив
    QuickSort(fTempArr, 0, length(fTempArr)-1);
    for i := 0 to Length(fNoSortArr[fIdx]) -1 do
    Begin
      fNoSortArr[fIdx][i] := fTempArr[i];
    End;
    setLength(fTempArr, 0);

  finally
    // Сотировка завершена
    CS.Enter;
    try
      GWorkerCnt := GWorkerCnt - 1;
    finally
      CS.Leave;
    end;
  end;
End;

// Сортировка массива Integer
procedure TThIntArrSorter.QuickSort( var a: array of integer; min, max: Integer);
Var
  i,j,
  mid,
  tmp
          : integer;
Begin
  if min < max then
  begin
    mid :=fTempArr [min];
    i := min-1;
    j := max+1;
    while i<j do
    begin
      repeat
        i:=i+1;
      until fTempArr[i]>=mid;

      repeat
        j := j - 1;
      until fTempArr[j] <= mid;

      if i < j then
      begin
        tmp:=fTempArr[i];
        fTempArr[i]:=fTempArr[j];
        fTempArr[j]:=tmp;
      end;
    end;

    QuickSort(a, min, j);
    QuickSort(a, j+1, max);
  end;
end;

//------------------------------ End TThIntArrSorter -------------------------------







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

    2: // Информация, полученная от потока ThSort
       Begin
         case msgVal of

           1..2 : // Завершился или прервался без аварии
                 Begin
                   fMain.b_FindFile.Enabled      := true;
                   fMain.cb_MultiThread.Enabled  := true;
                   fMain.b_FindFile.Caption      := 'Сортировать';

                 End;

           3 :   // Поток разрушен в деструкторе
                 Begin
                   thSort := nil;
                 End;

           4 :   // Одна из функций вернула ошибку
                 Begin
                   fMain.b_FindFile.Enabled      := true;
                   fMain.cb_MultiThread.Enabled  := true;
                   fMain.b_FindFile.Caption      := 'Сортировать';
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
    // Создаем файл если его нет (нужны проверки)
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


// Сохранение в файл
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

// Кастомная сортировка строк
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


function TThSorter.Sorting( ArrZipTable  : ZipTable ) : boolean;                // Sorting
  // Поиск в массиве соответствий по имени
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

    // Сортировка массива
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
Begin
  Result := false;
  sl := TStringList.Create;
  try

    for i := 0 to Length(GArrMatching)-1 do
    Begin
      if GArrMatching[i] <> '' then
        sl.Add(GArrMatching[i]);
    End;

    // Сортируем строчные данные
    sl.CustomSort(CompareStringsAscending);

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

      // Рисуем прогрес
      fPbCurPos := Round(i * 100 / (sl.Count-1));
      if fPbCurPos <>  fPbOldPos then
      Begin
        fPbOldPos := fPbCurPos;
        fMes := 'Сортировка прочитанных строчных данных: ' + IntToStr(fPbCurPos)+'%';
        Synchronize(ShowProgress);
      End;

      // Находим элемент в массиве соответствия, по имени
      fndIdx := FindIdxFromArrMatchByName( GArrMatching, sl.Strings[i] );
      if fndIdx >= 0 then
      Begin
        // Заполняем временный массив
        setLength( GSortedStrZipTable[i], length(ArrZipTable[fndIdx]) );
        for j := 0 to length(ArrZipTable[fndIdx]) -1 do
        begin
          GSortedStrZipTable[i][j] := ArrZipTable[fndIdx][j];
        end;

        // Если делать последовательно, без многопоточности
        if not fMultiTh then
        Begin

          // Сортируем Number часть
          SortIntArray( GSortedStrZipTable[i] );

          // Сохраняем в файл
          SaveToTxt( GSortedStrZipTable[i], sl.Strings[i] );
        End;
      End;
    End;

    // Многопоточный вариант
    if fMultiTh then
    Begin

      // Выполняем сортировку в разных потоках
      SetLength(ThSortWorker, length(GSortedStrZipTable));

      for i := 0 to length(GSortedStrZipTable)-1 do
      Begin
        ThSortWorker[i]            := TThIntArrSorter.Create(true);
        ThSortWorker[i].fNoSortArr := GSortedStrZipTable;
        ThSortWorker[i].priority   := tpLowest;
        ThSortWorker[i].fIdx       := i;

        // Рисуем прогрес
        fPbCurPos := Round(i * 100 / (length(GSortedStrZipTable)));
        if fPbCurPos <>  fPbOldPos then
        Begin
          fPbOldPos := fPbCurPos;
          fMes := 'Запускаем сортировку чисел: ' + IntToStr(fPbCurPos)+'%';
          Synchronize(ShowProgress);
        End;

        // Меняем переменную счетчик рабочих - потокобезопасно
        CS.Enter;
        try
          GWorkerCnt  := GWorkerCnt + 1;
        finally
          CS.Leave;
        end;

        ThSortWorker[i].Resume;
      End;

      // Таймер проверки, завершения работы потоков
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

        // Рисуем прогрес
        fPbCurPos := Round(i * 100 / ( sl.Count ));
        if fPbCurPos <>  fPbOldPos then
        Begin
          fPbOldPos := fPbCurPos;
          fMes := 'Записываем результат: ' + IntToStr(fPbCurPos)+'%';
          Synchronize(ShowProgress);
        End;

        // Сохраняем в файл
        SaveToTxt( GSortedStrZipTable[i], sl.Strings[i] );
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

  // Уникальность элемента
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

    // Читаем из файла порциями по 1025 байт
    while readEnd < maxFsSize do
    Begin

      // Ждем отмены от пользователя
      If Terminated then
      Begin
        fPbCurPos := 0;
        fMes := 'Операция прервана!';
        Synchronize(ShowProgress);
        // Сообщение в главную форму - Операция прервана
        PostMessage( fMain.Handle, WM_MY_SORT_INFO, 2, 2 );
        exit;
      End;


      if readEnd > readStart then
        readStart := readEnd;

      // Рисуем прогрес
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

        // Заполняем массив соответствий, найденными словами
        for j := 0 to readed do
        begin
          // Работаем со строками
          if buf[j] = ord(#13) then
          Begin
            bintoAscii( buf, found13+1, j-1, str, num);

            // Проверяем уникальность
            fndPosit := CheckIsArrElUnic(str, GArrMatching);
            case fndPosit of
              // Ошибка
              -1 : Begin

                   End;
              // Уникальная строка, будет первым элементом в fArrZipTable
              -2 : Begin
                    GArrMatching[arrMachInx] := str;
                    SetLength( fArrZipTable[arrMachInx], 1 );
                    fArrZipTable[arrMachInx][0] := StrToInt( copy(num, 1, pos('.',num)-1 ));
                    inc(arrMachInx);
                   End
              else
                  // Не уникальная строка, добавляем к динамическому массиву в fArrZipTable
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
 if fMain.b_FindFile.Caption = 'Выбрать' then
 begin
   od_InputFile.InitialDir := workDir;
   od_InputFile.Filter     := 'Текстовые файлы|*.txt';

   if od_InputFile.Execute then
   Begin
     inFilePath                    := od_InputFile.FileName;
     fMain.l_FilePath.caption      := 'Файл: ' + inFilePath;

     fMain.b_FindFile.Caption      := 'Сортировать';
     fMain.cb_MultiThread.visible  := true;
   End;
 end

 else

 if fMain.b_FindFile.Caption = 'Сортировать' then
 begin
    // Разблокируется при завершении потока - WMOnWM_MYINFO
    fMain.b_FindFile.Caption      := 'Прервать';
    fMain.cb_MultiThread.Enabled  := false;
    fMain.pb_Main.Visible         := true;

    if not Assigned(thSort) then
    Begin
      thSort    := TThSorter.Create();
      try
        // Передаем параметры в поток
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
  CS.Free;

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
  CS         := TCriticalSection.Create;
  GWorkerCnt := 0;
  // Размеры формы при resize
  with Constraints do
  Begin
        MaxHeight := 160;
        MinHeight := 160;
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

end.


