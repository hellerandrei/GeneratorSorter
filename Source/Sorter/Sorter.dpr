program Sorter;

uses
  Forms,
  Main in '..\..\Files\Main.pas' {fMain};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfMain, fMain);
  Application.Run;
end.
