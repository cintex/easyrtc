program RtcSrv;

uses
  FastMM4,
  Vcl.Forms,
  UFrmMain in 'UFrmMain.pas' {FrmMain},
  UGlobe in 'UGlobe.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmMain, FrmMain);
  Application.Run;
end.
