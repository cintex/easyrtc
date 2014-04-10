/// /////////////////////////////////////////////////////////////////////////////
//
// The MIT License
//
// Copyright (c) 2008 by Arcana Technologies Incorporated
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
/// /////////////////////////////////////////////////////////////////////////////

/// /////////////////////////////////////////////////////////////////////////////
// //
// unit Pooling.pas                                                          //
// Copyright 2003 by Arcana Technologies Incorporated                      //
// Written By Jason Southwell                                              //
// //
// Description:                                                              //
// This unit houses a class that implementats a generic pooling manager.   //
// //
// Updates:                                                                  //
// 04/03/2003 - TObjectPool Released to Open Source.                       //
// //
// License:                                                                  //
// This code is covered by the Mozilla Public License 1.1 (MPL 1.1)        //
// Full text of this license can be found at                               //
// http://www.opensource.org/licenses/mozilla1.1.html                      //
// //
/// /////////////////////////////////////////////////////////////////////////////

UNIT Pooling;

INTERFACE

USES{$IFDEF VER130}Windows,
  {$ENDIF}Classes,
  SysUtils,
  Uni,
  SyncObjs;

TYPE
  TObjectEvent = PROCEDURE(Sender: TObject; VAR AObject: TObject) OF OBJECT;

  TObjectPool = CLASS(TObject)
  private
    CS: TCriticalSection;
    ObjList: TList;
    ObjInUse: TBits;

    FActive: boolean;
    FAutoGrow: boolean;
    FGrowToSize: integer;
    FPoolSize: integer;
    FOnCreateObject: TObjectEvent;
    FOnDestroyObject: TObjectEvent;
    FUsageCount: integer;
    FRaiseExceptions: boolean;
  protected
  public
    CONSTRUCTOR Create; virtual;
    DESTRUCTOR Destroy; override;

    PROCEDURE Start(RaiseExceptions: boolean = False); virtual;
    PROCEDURE Stop; virtual;

    FUNCTION Acquire: TObject; virtual;
    PROCEDURE Release(CONST AItem: TObject); virtual;

    PROPERTY Active: boolean read FActive;
    PROPERTY RaiseExceptions: boolean read FRaiseExceptions
      write FRaiseExceptions;
    PROPERTY UsageCount: integer read FUsageCount;
    PROPERTY PoolSize: integer read FPoolSize write FPoolSize;
    PROPERTY AutoGrow: boolean read FAutoGrow write FAutoGrow;
    PROPERTY GrowToSize: integer read FGrowToSize write FGrowToSize;
    PROPERTY OnCreateObject: TObjectEvent read FOnCreateObject
      write FOnCreateObject;
    PROPERTY OnDestroyObject: TObjectEvent read FOnDestroyObject
      write FOnDestroyObject;
  END;

IMPLEMENTATION

{ TObjectPool }

FUNCTION TObjectPool.Acquire: TObject;
VAR
  idx: integer;
BEGIN
  Result := NIL;
  IF NOT FActive THEN
    BEGIN
      IF FRaiseExceptions THEN
        RAISE EAbort.Create('Cannot acquire an object before calling Start')
      ELSE
        exit;
    END;
  CS.Enter;
  TRY
    Inc(FUsageCount);
    idx := ObjInUse.OpenBit;
    IF idx < FPoolSize THEN // idx = FPoolSize when there are no openbits
      BEGIN
        Result := Objlist[idx];
        ObjInUse[idx] := True;
      END
    ELSE
      BEGIN
        // Handle the case where the pool is completely acquired.
        IF NOT AutoGrow OR (FPoolSize > FGrowToSize) THEN
          BEGIN
            IF FRaiseExceptions THEN
              RAISE
                Exception.Create('There are no available objects in the pool')
            ELSE
              Exit;
          END;
        inc(FPoolSize);
        ObjInUse.Size := FPoolSize;
        FOnCreateObject(Self, Result);
        ObjList.Add(Result);
        ObjInUse[FPoolSize - 1] := True;
      END;
  FINALLY
    CS.Leave;
  END;
END;

CONSTRUCTOR TObjectPool.Create;
BEGIN
  CS := TCriticalSection.Create;
  ObjList := TList.Create;
  ObjInUse := TBits.Create;

  FActive := False;
  FAutoGrow := False;
  FGrowToSize := 20;
  FPoolSize := 20;
  FRaiseExceptions := True;
  FOnCreateObject := NIL;
  FOnDestroyObject := NIL;
END;

DESTRUCTOR TObjectPool.Destroy;
BEGIN
  IF FActive THEN
    Stop;
  CS.Free;
  ObjList.Free;
  ObjInUse.Free;
  INHERITED;
END;

PROCEDURE TObjectPool.Release(CONST AItem: TObject);
VAR
  idx: integer;
BEGIN
  IF NOT FActive THEN
    BEGIN
      IF FRaiseExceptions THEN
        RAISE Exception.Create('Cannot release an object before calling Start')
      ELSE
        exit;
    END;
  IF NOT Assigned(AItem) THEN
    BEGIN
      IF FRaiseExceptions THEN
        RAISE Exception.Create('Cannot release an object before calling Start')
      ELSE
        exit;
    END;
  CS.Enter;
  TRY
    idx := ObjList.IndexOf(AItem);
    IF idx < 0 THEN
      BEGIN
        IF FRaiseExceptions THEN
          RAISE Exception.Create
            ('Cannot release an object that is not in the pool')
        ELSE
          exit;
      END;
    ObjInUse[idx] := False;

    Dec(FUsageCount);
  FINALLY
    CS.Leave;
  END;
END;

PROCEDURE TObjectPool.Start(RaiseExceptions: boolean = False);
VAR
  i: integer;
  o: TObject;
BEGIN
  IF Active THEN
    Exit;
  // Make sure events are assigned before starting the pool.
  IF NOT Assigned(FOnCreateObject) THEN
    RAISE Exception.Create
      ('There must be an OnCreateObject event before calling Start');
  IF NOT Assigned(FOnDestroyObject) THEN
    RAISE Exception.Create
      ('There must be an OnDestroyObject event before calling Start');

  // Set the TBits class to the same size as the pool.
  ObjInUse.Size := FPoolSize;

  // Call the OnCreateObject event once for each item in the pool.
  FOR i := 0 TO FPoolSize - 1 DO
    BEGIN
      o := NIL;                               
      FOnCreateObject(Self, o);
 
      ObjList.Add(o);
      ObjInUse[i] := False;
    END;

  // Set the active flag to true so that the Acquire method will return values.
  FActive := True;

  // Automatically set RaiseExceptions to false by default.  This keeps
  // exceptions from being raised in threads.
  FRaiseExceptions := RaiseExceptions;
END;

PROCEDURE TObjectPool.Stop;
VAR
  i: integer;
  o: TObject;
BEGIN
  IF NOT Active THEN
    Exit;
  // Wait until all objects have been released from the pool.  After waiting
  // 10 seconds, stop anyway.  This may cause unforseen problems, but usually
  // you only Stop a pool as the application is stopping.  40 x 250 = 10,000
  FOR i := 1 TO 40 DO
    BEGIN
      CS.Enter;
      TRY
        // Setting Active to false here keeps the Acquire method from continuing to
        // retrieve objects.
        FActive := False;
        IF FUsageCount = 0 THEN
          break;
      FINALLY
        CS.Leave;
      END;
      // Sleep here to allow give threads time to release their objects.
      Sleep(250);
    END;

  CS.Enter;
  TRY
    // Loop through all items in the pool calling the OnDestroyObject event.
    FOR i := 0 TO FPoolSize - 1 DO
      BEGIN
        o := ObjList[i];
        IF Assigned(FOnDestroyObject) THEN
          FOnDestroyObject(Self, o)
        ELSE
          o.Free;
      END;

    // clear the memory used by the list object and TBits class.
    ObjList.Clear;
    ObjInUse.Size := 0;
    FPoolSize := 0;
    FRaiseExceptions := True;
  FINALLY
    CS.Leave;
  END;
END;

END.

