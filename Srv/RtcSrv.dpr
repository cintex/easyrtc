PROGRAM RtcSrv;

USES
  FastMM4,
  Vcl.Forms,
  UFrmMain IN 'UFrmMain.pas' {FrmMain},
  UGlobe IN 'UGlobe.pas';

{$R *.res}

BEGIN
  Application.Initialize;
  Application.MainFormOnTaskbar := false;
  Application.CreateForm(TFrmMain, FrmMain);
  Application.ShowMainForm := false;
  Application.Run;
END.

