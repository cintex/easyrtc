UNIT UFrmMain;

INTERFACE

USES
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.Menus,
  Vcl.StdCtrls,
  //SYSTEM
  adodb,
  psAPI,
  //RTC
  rtclog,
  rtcactivex,
  rtcDataSrv,
  rtcInfo,
  rtcConn,
  rtcdb,
  rtczlib,
  rtcHttpSrv,
  //3TD
  pooling,
  dxGDIPlusClasses,
  //PROUNIT
  UGlobe;

TYPE
  TFrmMain = CLASS(TForm)
    img_logo: TImage;
    trycn_main: TTrayIcon;
    pm_main: TPopupMenu;
    tmr_main: TTimer;
    lbl1: TLabel;
    lbl2: TLabel;
    lbl3: TLabel;
    lbl4: TLabel;
    lbl5: TLabel;
    lbl6: TLabel;
    lbl7: TLabel;
    lbl8: TLabel;
    lbl9: TLabel;
    lbl10: TLabel;
    lbl11: TLabel;
    lbl12: TLabel;
    ShowMainFrom1: TMenuItem;
    N1: TMenuItem;
    Exit1: TMenuItem;
    PROCEDURE FormCreate(Sender: TObject);
    PROCEDURE FormDestroy(Sender: TObject);
    PROCEDURE tmr_mainTimer(Sender: TObject);
    PROCEDURE ShowMainFrom1Click(Sender: TObject);
    PROCEDURE Exit1Click(Sender: TObject);
    PROCEDURE FormCloseQuery(Sender: TObject; VAR CanClose: Boolean);
  private
    { Private declarations }
    RtcHs: TRtcHttpServer;
    RtcDp: TRtcDataProvider;
    Fpool: TObjectPool;
    FTotalRequest, FTotalDataIn, FTotalDataOut, FTime: int64;
    PROCEDURE RtcDpCheckRequest(Sender: TRtcConnection);
    PROCEDURE RtcDpDataReceived(Sender: TRtcConnection);
    PROCEDURE RtcHsDataIn(Sender: TRtcConnection);
    PROCEDURE RtcHsDataOut(Sender: TRtcConnection);

    PROCEDURE CreateQuery(Sender: TObject; VAR AObject: TObject);
    PROCEDURE DestroyQuery(Sender: TObject; VAR AObject: TObject);

    PROCEDURE ReqQry(Sender: TRtcConnection);
    PROCEDURE ReqSql(Sender: TRtcConnection);
    PROCEDURE ReqFile(Sender: TRtcConnection);
    PROCEDURE ReqPing(Sender: TRtcConnection);
    PROCEDURE ReqLogin(Sender: TRtcConnection);

    FUNCTION getSysInfo: RtcString;
  public
    { Public declarations }
    PROCEDURE StartSrv;
    PROCEDURE StopSrv;
  END;

VAR
  FrmMain: TFrmMain;

IMPLEMENTATION

{$R *.dfm}

{ TFrmMain }

PROCEDURE TFrmMain.CreateQuery(Sender: TObject; VAR AObject: TObject);
VAR
  qry: TAdoQuery;
  conn: TADOConnection;
BEGIN
  conn := TADOConnection.Create(NIL);
  conn.ConnectionString := GSysCfg.as_String['CONN'];
  conn.CursorLocation := clUseServer;
  qry := TAdoQuery.Create(NIL);
  qry.Connection := conn;
  AObject := qry;
END;

PROCEDURE TFrmMain.DestroyQuery(Sender: TObject; VAR AObject: TObject);
VAR
  qry: TAdoQuery;
  conn: TADOConnection;
BEGIN
  qry := TAdoQuery(AObject);
  conn := qry.Connection;
  FreeAndNil(qry);
  FreeAndNil(conn);
  AObject := NIL;
END;

PROCEDURE TFrmMain.Exit1Click(Sender: TObject);
BEGIN
  StopSrv;
  Halt(0);
END;

PROCEDURE TFrmMain.FormCloseQuery(Sender: TObject; VAR CanClose: Boolean);
BEGIN
  CanClose := NOT GSysCfg.asBoolean['CLOSE2HIDE'];
  hide;
END;

PROCEDURE TFrmMain.FormCreate(Sender: TObject);
BEGIN
  XLog('______________________________________________________');
  XLog('System start¡­¡­');
  RtcHs := TRtcHttpServer.Create(FrmMain);
  RtcDp := TRtcDataProvider.Create(FrmMain);
  RtcHs.Name := 'RtcHs';
  RtcHs.MultiThreaded := True;
  RtcHs.RestartOn.ListenLost := True;
  RtcHs.RestartOn.ListenError := True;
  RtcHs.FixupRequest.UpperCaseFileName := True;
  RtcHs.OnDataOut := FrmMain.RtcHsDataOut;
  RtcHs.OnDataIn := FrmMain.RtcHsDataIn;

  //RtcDp
  RtcDp.Name := 'RtcDp';
  RtcDp.Server := RtcHs;
  RtcDp.OnCheckRequest := FrmMain.RtcDpCheckRequest;
  RtcDp.OnDataReceived := FrmMain.RtcDpDataReceived;

  Fpool := TObjectPool.create();
  Fpool.OnCreateObject := CreateQuery;
  Fpool.OnDestroyObject := DestroyQuery;
  XLog('System start load system config¡­¡­');
  LoadSysCfg;
  Caption := GSysCfg.asString['SYSNAME'];
  XLog('System start HTTP server¡­¡­');
  startsrv;
  XLog('System startHTTP server OK');
  XLog('System start OK');
END;

PROCEDURE TFrmMain.FormDestroy(Sender: TObject);
BEGIN
  XLog('System exit¡­¡­');
  XLog('System closeHTTP server¡­¡­');
  stopsrv;
  XLog('System closeHTTP server OK');
  FreeAndNil(FPool);
  XLog('System exit OK');
  XLog('______________________________________________________');
END;

FUNCTION TFrmMain.getSysInfo: RtcString;
VAR
  pmc: PPROCESS_MEMORY_COUNTERS;
  cb: Integer;
  SysInfo: TRtcRecord;
BEGIN
  SysInfo := TRtcRecord.Create;
  WITH SysInfo DO
    TRY
      asLargeInt['UsageCount'] := Fpool.UsageCount;
      asInteger['PoolSize'] := Fpool.PoolSize;
      asInteger['ConnectionCount'] := rtchs.TotalServerConnectionCount;
      asLargeInt['TotalDataIn'] := FtotalDataIn;
      asLargeInt['ServerTime'] := (gettickcount - FTime)div 1000;
      asLargeInt['TotalDataOut'] := FTotalDataOut;
      asLargeInt['TotalRequest'] := FTotalRequest;
      cb := SizeOf(_PROCESS_MEMORY_COUNTERS);
      GetMem(pmc, cb);
      pmc^.cb := cb;
      IF GetProcessMemoryInfo(GetCurrentProcess(), pmc, cb) THEN
        asLargeInt['MemoryUsed'] := pmc^.WorkingSetSize;
      FreeMem(pmc);
      result := SysInfo.toJSON;
    FINALLY
      SysInfo.Kill;
    END;
END;

PROCEDURE TFrmMain.ReqFile(Sender: TRtcConnection);
VAR
  requri, ext: RtcString;
BEGIN
  WITH TRtcHttpServer(Sender) DO
    BEGIN
      requri := GetFileName(request.FileName);
      ext := uppercase(extractfileext(requri));
      IF NOT File_Exists(requri) THEN
        BEGIN
          Response.Status(404, 'File not found');
          Write('Status 404: File not found');
        END
      ELSE
        BEGIN
          Response.ContentType := GetContentType(requri);
          IF (Pos('deflate', Request.Value['Accept-Encoding']) > 0)
            AND (file_size(requri) > 4096)
            AND (Pos(ext, GSysCfg.asText['ZIPEXT']) > 0) THEN
            BEGIN
              Response.Value['Content-Encoding'] := 'deflate';
              Write(ZCompress_Str(Read_File(requri), zcFastest));
            END
          ELSE
            Write(Read_File(requri));
        END;
    END;
END;

PROCEDURE TFrmMain.ReqLogin(Sender: TRtcConnection);
VAR
  qry: tAdoquery;
  i: integer;
  res: TRtcRecord;
BEGIN
  WITH TRtcHttpServer(Sender), request DO
    IF findSession(query.ValueCS['SID']) THEN
      write('1')
    ELSE
      BEGIN
        opensession(sesIPLock);
        qry := tAdoquery(Fpool.Acquire);
        WITH qry DO
          TRY
            qry.close;
            SQL.Text := GDbCfg.asString['LOGIN'];
            Prepared := true;
            FOR i := 0 TO Parameters.Count - 1 DO
              Parameters.FindParam(Parameters.Items[i].Name).Value := info.asrecord['REQ'].Value[Parameters.Items[i].Name];
            open;
            IF recordcount = 1 THEN
              BEGIN
                res := TRtcRecord.Create;
                TRY
                  res.asString['SID'] := session.ID;
                  res.asString['SYSNAME'] := GSysCfg.asString['SYSNAME'];
                  FOR i := 0 TO FieldCount - 1 DO
                    BEGIN
                      res.asValue[Fields.Fields[i].FieldName] := Fields.Fields[i].AsVariant;
                    END;
                  write(res.toJSON);
                  close;
                FINALLY
                  res.Kill;
                END;
              END
            ELSE
              write(jsonerror('ERRORNP'));
          FINALLY
            Fpool.Release(qry);
          END;
      END;
END;

PROCEDURE TFrmMain.ReqPing(Sender: TRtcConnection);
BEGIN
  WITH TRtcHttpServer(Sender), request DO
    IF findSession(info.asrecord['REQ'].as_String['SID']) THEN
      write('1')
    ELSE
      write('0');
END;

PROCEDURE TFrmMain.ReqQry(Sender: TRtcConnection);
VAR
  qry: tadoquery;
  i: integer;
  rtc: TRtcValue;
BEGIN
  WITH TRtcHttpServer(Sender), request, query DO
    BEGIN
      qry := tadoquery(Fpool.Acquire);

      WITH qry DO
        TRY
          TRY
            SQL.Text := GDbCfg.asValue[info.asrecord['REQ'].asString['CODE']];
            Prepared := true;
            FOR i := 0 TO Parameters.Count - 1 DO
              Parameters.FindParam(Parameters.Items[i].Name).Value := info.asrecord['REQ'].Value[Parameters.Items[i].Name];
            open;

            rtc := TRtcValue.Create;
            IF info.asrecord['REQ'].asString['RT'] = 'DS' THEN
              BEGIN
                DelphiDataSetToRtc(qry, rtc.NewDataSet);
                write(rtc.toJSON);
              END
            ELSE
              BEGIN
                DelphiDataSetToRtcArray(qry, rtc.NewArray);
                write(format('{"total":%d,"rows":%s}', [qry.RecordCount, rtc.toJSON]));
              END;
            close;
          EXCEPT
            ON e: exception DO
              BEGIN
                write(jsonerror(e.message));
                close;
              END;
          END;
        FINALLY
          Fpool.Release(qry);
        END;
    END;
END;

PROCEDURE TFrmMain.ReqSql(Sender: TRtcConnection);
VAR
  qry: tAdoQuery;
  i: integer;
BEGIN
  WITH TRtcHttpServer(Sender), request DO
    BEGIN
      qry := TAdoQuery(FPool.Acquire);
      WITH qry, TRtcHttpServer(Sender), Request, query DO
        TRY
          TRY
            connection.BeginTrans;
            SQL.Text := GDbCfg.as_String[info.asrecord['REQ'].asString['CODE']];
            Prepared := true;
            FOR i := 0 TO Parameters.Count - 1 DO
              Parameters.FindParam(Parameters.Items[i].Name).Value := info.asrecord['REQ'].Value[Parameters.Items[i].Name];
            execsql;
            connection.CommitTrans;

            write(format('%d', [RowsAffected]));
          EXCEPT
            ON e: exception DO
              BEGIN
                write(jsonerror(e.Message));
                connection.RollbackTrans;
              END;
          END;
        FINALLY
          FPool.Release(qry);
        END;
    END;
END;

PROCEDURE TFrmMain.RtcDpCheckRequest(Sender: TRtcConnection);
BEGIN
  WITH TRtcHttpServer(sender) DO
    accept;
END;

PROCEDURE TFrmMain.RtcDpDataReceived(Sender: TRtcConnection);
VAR
  rtc: TRtcRecord;
BEGIN
  WITH TRtcHttpServer(Sender), Request, Response DO
    BEGIN
      IF Started THEN
        query.AddText(read());
      IF complete THEN
        BEGIN
          response.ContentType := 'application/x-javascript;charset=utf-8;';
          IF request.Value['Connection'] = 'keep-alive' THEN
            response.Value['Connection'] := 'keep-alive';
          IF query.Text = '' THEN
            query.Text := '{}';
          TRY
            rtc := TRtcRecord.FromJSON(url_decode(query.Text));
          EXCEPT
            write(JsonError('NOTJSON'));
            exit;
          END;
          request.Info.asRecord['REQ'] := rtc;
          IF (filename = '/REST') AND (method = 'GET') THEN
            reqQry(sender)
          ELSE
            IF (filename = '/REST') AND (method = 'POST') THEN
            reqsql(sender)
          ELSE
            IF filename = '/PING' THEN
            reqPing(sender)
          ELSE
            IF filename = '/SYS' THEN
            write(getSysInfo)
          ELSE
            IF filename = '/LOGIN' THEN
            reqLogin(sender)
          ELSE
            reqFile(sender);
          rtc.Kill;
        END;
    END;
END;

PROCEDURE TFrmMain.RtcHsDataIn(Sender: TRtcConnection);
BEGIN
  IF NOT Sender.inMainThread THEN
    Sender.Sync(RtcHsDataIn)
  ELSE
    FTotalDataIn := FTotalDataIn + Sender.DataIn;
END;

PROCEDURE TFrmMain.RtcHsDataOut(Sender: TRtcConnection);
BEGIN
  IF NOT Sender.inMainThread THEN
    Sender.Sync(RtcHsDataOut)
  ELSE
    FTotalDataOut := FTotalDataOut + Sender.DataOut;
END;

PROCEDURE TFrmMain.ShowMainFrom1Click(Sender: TObject);
BEGIN
  IF Self.Showing THEN
    Self.Hide
  ELSE
    Self.Show;
END;

PROCEDURE TFrmMain.StartSrv;
BEGIN
  IF NOT RtcHs.isListening THEN
    WITH rtchs DO
      BEGIN
        tmr_Main.Enabled := true;
        ServerAddr := GSysCfg.as_string['ADDR'];
        ServerPort := GSysCfg.as_string['PORT'];
        FTime := GetTickCount;
        FTotalRequest := 0;
        FTotalDataIn := 0;
        FTotalDataOut := 0;
        RtcHs.Listen;
        FPool.Start();
      END;
END;

PROCEDURE TFrmMain.StopSrv;
BEGIN
  IF RtcHs.isListening THEN
    BEGIN
      tmr_Main.Enabled := false;
      RtcHs.StopListenNow;
      FPool.Stop();
    END;
END;

PROCEDURE TFrmMain.tmr_mainTimer(Sender: TObject);
VAR
  rtc: TRtcRecord;
  yy, mm, dd, hh, mi, ss, tt: WORD;
  dt: TDateTime;
BEGIN
  rtc := TRtcRecord.FromJSON(getSysInfo);
  TRY
    lbl4.Caption := BytesToStr(rtc.asLargeInt['TotalDataIn']);
    lbl5.Caption := BytesToStr(rtc.asLargeInt['TotalDataOut']);
    lbl6.Caption := BytesToStr(rtc.asLargeInt['ConnectionCount']);
    lbl10.Caption := ConvertTimeToTimestr(rtc.asLargeInt['ServerTime']);
    lbl11.Caption := BytesToStr(rtc.asInteger['PoolSize']);
    lbl12.Caption := BytesToStr(rtc.asLargeInt['MemoryUsed']);
  FINALLY
    rtc.kill;
  END;
END;

END.

