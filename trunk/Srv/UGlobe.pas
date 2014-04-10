UNIT UGlobe;

INTERFACE
USES
  classes,
  sysutils,
  strutils,
  windows,
  rtclog,
  rtcinfo;

VAR
  GSysCfg, GDbCfg: TRtcRecord;
  GAppPath, GDocRoot: RtcString;

FUNCTION JsonError(CONST msg: RtcString): RtcString;
PROCEDURE LoadSysCfg;
FUNCTION BytesToStr(CONST i64Size: int64): STRING;

FUNCTION GetFileName(CONST fn: STRING): STRING;
FUNCTION GetContentType(CONST fn: STRING): STRING;

IMPLEMENTATION

FUNCTION BytesToStr(CONST i64Size: int64): STRING;
CONST
  i64GB = 1073741824;
  i64MB = 1048576;
  i64KB = 1024;
BEGIN
  IF i64Size DIV i64GB > 0 THEN
    Result := Format('%.2fG', [i64Size / i64GB])
  ELSE
    IF i64Size DIV i64MB > 0 THEN
    Result := Format('%.2fM', [i64Size / i64MB])
  ELSE
    IF i64Size DIV i64KB > 0 THEN
    Result := Format('%.2fK', [i64Size / i64KB])
  ELSE
    Result := IntToStr(i64Size);
END;

PROCEDURE LoadSysCfg;
VAR
  ts: TStrings;
  i: integer;
BEGIN
  ts := TStringList.Create;
  TRY
    TRY
      ts.LoadFromFile(GAppPath + 'Server.Cfg');
      GSysCfg := TRtcRecord.FromJSON(stringreplace(ts.Text, #13#10, '', [rfReplaceAll]));
      ts.LoadFromFile(GAppPath + 'Sql.Cfg');
      GDbCfg := TRtcRecord.FromJSON(stringreplace(ts.Text, #13#10, '', [rfReplaceAll]));
    EXCEPT
      ON e: exception DO
        BEGIN
          Xlog(e.Message);
          halt;
        END;
    END;
  FINALLY
    freeandnil(ts);
  END;
END;

FUNCTION GetContentType(CONST fn: STRING): STRING;
VAR
  ext: STRING;
BEGIN
  ext := UpperCase(ExtractFileExt(fn));
  Result := GSysCfg.as_string[ext];
END;

FUNCTION GetFileName(CONST fn: STRING): STRING;
BEGIN
  IF fn = '/' THEN
    result := Format('%s/index.html', [GDocRoot])
  ELSE
    result := Format('%s%s', [GDocRoot, fn]);
  result := StringReplace(result, '../', '\', [rfReplaceAll]);
  result := StringReplace(result, '/', '\', [rfReplaceAll]);
  result := StringReplace(result, '\\', '\', [rfReplaceAll]);
END;

FUNCTION JsonError(CONST msg: RtcString): RtcString;
BEGIN
  result := format('{"ERR":"%s"}', [msg]);
END;
INITIALIZATION
  GAppPath := extractfilepath(ParamStr(0));
  GDocRoot := extractfilepath(ParamStr(0)) + 'WebRoot';
FINALIZATION
  IF GSysCfg <> NIL THEN
    GSysCfg.Kill;
  IF GDbCfg <> NIL THEN
    GDbCfg.Kill;
END.

