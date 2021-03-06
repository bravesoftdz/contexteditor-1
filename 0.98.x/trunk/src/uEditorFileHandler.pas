// Copyright (c) 2009, ConTEXT Project Ltd
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// Neither the name of ConTEXT Project Ltd nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

unit uEditorFileHandler;

interface

{$I ConTEXT.inc}

uses
  Windows, Messages, SysUtils, Classes, Forms, Dialogs, Controls,
  uCommon, uFileHist, FileCtrl, uMultiLanguage, SynEditTextBuffer,
  SynEditTypes, JclFileUtils;

type
  TEditorFileHandler = class
  private
    fEditor: TObject;
    fSavedMemoCaret: TBufferCoord;
    fSavedMemoFirstLine: integer;
    fSavedMemoLeftChar: integer;
    function GetBackupFilename: string;
    procedure RememberMemoPositions;
    procedure RestoreMemoPositions;
  public
    constructor Create(Editor: TObject);

    // todo: move to private
    function SaveInFormat(Source: TStrings; Format: TTextFormat; FileName: string): boolean;
    function PrepareForSave(var NewFileName:string; const ChangeName:boolean = FALSE):boolean;

    function BackupFile: boolean;
    function Rename(NewFileName: string): boolean;
    function RenameEnabled: boolean;
    function RevertToSavedEnabled: boolean;
    function RevertToBackupEnabled: boolean;
    procedure RevertToSaved;
    procedure RevertToBackup;
    procedure CopyTo;
  end;

implementation

uses
  fEditor, uEnvOptions;


////////////////////////////////////////////////////////////////////////////////////////////
//                                     Functions
////////////////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------------------
function TEditorFileHandler.GetBackupFilename: string;
var
  path: string;
  bak_fname: string;
  fname: string;
begin
  fname:=TfmEditor(fEditor).FileName;

  if (Length(EnvOptions.BackupDir)>0) then
    path:=PathAddSeparator(EnvOptions.BackupDir)
  else
    path:=ExtractFilePath(fname);

  bak_fname:=ExtractFileName(fname);

  if EnvOptions.BackupDOSFileName then
    SetLength(bak_fname, Length(bak_fname)-Length(ExtractFileExt(bak_fname)));

  result:=path+bak_fname+'.bak';
end;
//------------------------------------------------------------------------------------------
procedure TEditorFileHandler.RememberMemoPositions;
begin
  with TfmEditor(fEditor).memo do begin
    fSavedMemoCaret:=CaretXY;
    fSavedMemoFirstLine:=TopLine;
    fSavedMemoLeftChar:=LeftChar;
  end;
end;
//------------------------------------------------------------------------------------------
procedure TEditorFileHandler.RestoreMemoPositions;
begin
  with TfmEditor(fEditor).memo do begin
    CaretXY:=fSavedMemoCaret;
    TopLine:=fSavedMemoFirstLine;
    LeftChar:=fSavedMemoLeftChar;
  end;
end;
//------------------------------------------------------------------------------------------
function TEditorFileHandler.BackupFile: boolean;
var
  bak_fname: string;
  bak_path: string;
  ok: boolean;
  attr: word;
  fname: string;
begin
  ok:=TRUE;
  fname:=TfmEditor(fEditor).FileName;

  if EnvOptions.BackupFile and FileExists(fname) then begin
    bak_fname:=GetBackupFilename;
    bak_path:=ExtractFilePath(bak_fname);

    if (Length(EnvOptions.BackupDir)>0) then
      ForceDirectories(bak_path);

    if FileExists(bak_fname) then begin
      attr:=FileGetAttr(bak_fname);
      FileSetAttr(bak_fname, attr and not faReadOnly);
      DeleteFile(bak_fname);
    end;

    ok:=CopyFile(PChar(fname), PChar(bak_fname), FALSE);

    if not ok then
      MessageDlg(Format(mlStr(ML_EDIT_ERR_SAVING_BACKUP,'Error creating backup file: ''%s'''),[bak_fname]),
                 mtError,[mbOK],0);
  end;

  result:=ok;
end;
//------------------------------------------------------------------------------------------
function TEditorFileHandler.RenameEnabled: boolean;
var
  Editor: TfmEditor;
begin
  Editor:=TfmEditor(fEditor);
  result:=not (Editor.NewFile or Editor.Unnamed);
end;
//------------------------------------------------------------------------------------------
function TEditorFileHandler.Rename(NewFileName: string): boolean;
var
  old_fname: string;
  old_path: string;
  new_path: string;
  Editor: TfmEditor;
begin
  Editor:=TfmEditor(fEditor);

  old_fname:=Editor.FileName;
  old_path:=ExtractFilePath(Editor.FileName);
  new_path:=ExtractFilePath(NewFileName);
  Delete(NewFileName, 1, Length(new_path));

  if (Length(new_path)=0) then
    new_path:=old_path;

  NewFileName:=new_path+NewFileName;

  if (not FileExists(NewFileName)) or (UpperCase(NewFileName)=UpperCase(Editor.FileName)) then begin
    result:=RenameFile(Editor.FileName, NewFileName);
    if not result then
      MessageDlg(Format(mlStr(ML_RENAME_FILE_ERROR, 'Error renaming file ''%s'' to ''%s''.'), [Editor.FileName, NewFileName]),
                 mtError, [mbOK], 0);
  end else begin
    MessageDlg(mlStr(ML_RENAME_FILE_ERR_EXISTS, 'File already exists!'), mtError, [mbOK], 0);
    result:=FALSE;
  end;

  if result then
    Editor.FileName:=NewFileName;
end;
//------------------------------------------------------------------------------------------
function TEditorFileHandler.RevertToBackupEnabled: boolean;
begin
  result:=EnvOptions.BackupFile and FileExists(GetBackupFilename);
end;
//------------------------------------------------------------------------------------------
procedure TEditorFileHandler.RevertToBackup;
var
  OldFileName: string;
  Editor: TfmEditor;
begin
  if (MessageDlg(Format(mlStr(ML_REVERT_TO_BACKUP_QUERY, 'Revert to backup file ''%s''?'), [GetBackupFilename]), mtWarning, [mbOK, mbCancel], 0)=mrOK) then begin
    Editor:=TfmEditor(fEditor);
    OldFileName:=Editor.FileName;
    RememberMemoPositions;
    Editor.Open(GetBackupFilename, FALSE);
    RestoreMemoPositions;
    Editor.FileName:=OldFileName;
    Editor.Modified:=TRUE;
  end;
end;
//------------------------------------------------------------------------------------------
function TEditorFileHandler.RevertToSavedEnabled: boolean;
var
  Editor: TfmEditor;
begin
  Editor:=TfmEditor(fEditor);
  result:=Editor.Modified and not (Editor.NewFile or Editor.Unnamed);
end;
//------------------------------------------------------------------------------------------
procedure TEditorFileHandler.RevertToSaved;
var
  Editor: TfmEditor;
begin
  Editor:=TfmEditor(fEditor);
  if (MessageDlg(Format(mlStr(ML_REVERT_TO_SAVED_QUERY, 'Revert ''%s'' to saved?'), [Editor.FileName]), mtWarning, [mbOK, mbCancel], 0)=mrOK) then begin
    RememberMemoPositions;
    Editor.Open(Editor.FileName, FALSE);
    RestoreMemoPositions;
  end;
end;
//------------------------------------------------------------------------------------------
function TEditorFileHandler.SaveInFormat(Source: TStrings; Format: TTextFormat; FileName: string): boolean;
var
  buff      :pChar;
  buff_size :integer;
  p, pp     :pChar;
  s         :string;
  i         :integer;
  F         :file;
  ok        :boolean;
begin
  ok:=TRUE;

  try
    case format of
      tfNormal:
        begin
          TSynEditStringList(Source).FileFormat:=sffDos;
          Source.SaveToFile(FileName);
          ok:=TRUE;
        end;
      tfUnix:
        begin
          TSynEditStringList(Source).FileFormat:=sffUnix;
          Source.SaveToFile(FileName);
          ok:=TRUE;
        end;
      tfMac:
        begin
          TSynEditStringList(Source).FileFormat:=sffMac;
          Source.SaveToFile(FileName);
          ok:=TRUE;
        end;
      tfUnicode, tfUnicodeBigEndian, tfUTF8:
        begin
          buff:=nil;

          case format of
            tfUnicode:
              begin
                buff_size:=2+Length(Source.Text)*2;
                GetMem(buff,buff_size);
                p:=buff;
                p^:=#$FF;
                (p+1)^:=#$FE;
                inc(p,2);
                s:=Source.Text;
                for i:=1 to Length(s) do begin
                  p^:=s[i];
                  (p+1)^:=#00;
                  inc(p,2);
                end;
              end;
            tfUnicodeBigEndian:
              begin
                buff_size:=2+Length(Source.Text)*2;
                GetMem(buff,buff_size);
                p:=buff;
                p^:=#$FE;
                (p+1)^:=#$FF;
                inc(p,2);
                s:=Source.Text;
                for i:=1 to Length(s) do begin
                  p^:=#00;
                  (p+1)^:=s[i];
                  inc(p,2);
                end;
              end;
            tfUTF8:
              begin
                buff_size:=3+Length(Source.Text);
                GetMem(buff,buff_size);
                p:=buff;
                p^:=#$EF;
                (p+1)^:=#$BB;
                (p+2)^:=#$BF;
                inc(p,3);
                pp:=@Source.Text[1];
                Move(pp^, p^, Length(Source.Text));
              end;
          end;

          AssignFile(F, FileName);
          {$I-} Rewrite(F,1); {$I+}
          ok:=(IOResult=0);

          if ok then begin
            BlockWrite(F, buff^,buff_size);
            System.CloseFile(F);
          end;

          if Assigned(buff) then
            FreeMem(buff);
        end;
    end;
  except
    ok:=FALSE;
  end;

  result:=ok;
end;
//------------------------------------------------------------------------------------------
function TEditorFileHandler.PrepareForSave(var NewFileName:string; const ChangeName:boolean = FALSE):boolean;
var
  canceled: boolean;
  dlg: TSaveDialog;
  s: string;
  OldExt: string;
  OldFilterIndex: integer;
  attr: integer;
  Editor: TfmEditor;
label
  EXECUTE_DIALOG;

  function FirstMask_From_NewFilter:string;
  begin
    result:=GetDefaultExtForFilterIndex(dlg.Filter, dlg.FilterIndex);
  end;

begin
  Editor:=TfmEditor(fEditor);

  canceled:=FALSE;
  NewFileName:=Editor.FileName;

  dlg:=TSaveDialog.Create(nil);
  try
    dlg.Options:=[ofHideReadOnly,ofEnableSizing];

    if (Length(Editor.FileName)=0) or ChangeName or (Editor.NewFile and Editor.Unnamed) then begin
      PrepareOpenDlgForFileType(dlg, Editor);

      if not Editor.NewFile then begin
        s:=ExtractFileExt(Editor.FileName);
        dlg.FileName:=Copy(Editor.FileName,1, Length(Editor.FileName)-Length(s));
        if (Length(s)>0) and (s[1]='.') then Delete(s,1,1);
        OldExt:=s;
      end else begin
        dlg.FileName:='';
        OldExt:='';
      end;

      dlg.DefaultExt:='';
      OldFilterIndex:=dlg.FilterIndex;

      BringEditorToFront(Editor);

      EXECUTE_DIALOG:
        canceled:=not dlg.Execute;

        if not canceled then begin
          s:=dlg.FileName;
          if (Pos('.',ExtractFileName(dlg.FileName))=0) then begin
            if (OldExt<>'') and (OldFilterIndex=dlg.FilterIndex) then
              s:=s+'.'+OldExt
            else
              if (dlg.FilterIndex<>1) then
                s:=s+'.'+FirstMask_From_NewFilter;
          end;

          if DlgReplaceFile(s) then
            NewFileName:=s
          else
            goto EXECUTE_DIALOG;
        end;
    end;
  finally
    dlg.Free;
  end;

  if not canceled then begin
    attr:=FileGetAttr(NewFileName);
    if (attr<>-1) and ((attr and faReadOnly)>0) then begin
      canceled:=MessageDlg(Format(mlStr(ML_EDIT_READ_ONLY_WARNING, 'File ''%s'' is read-only. Save file anyway?'), [NewFileName]),
                           mtWarning, [mbOK, mbCancel], 0)=mrCancel;

      if not canceled then
        FileSetAttr(NewFileName, attr and not faReadOnly);
    end;
  end;

  result:=not canceled;
end;
//------------------------------------------------------------------------------------------
procedure TEditorFileHandler.CopyTo;
var
  fname: string;
  Editor: TfmEditor;
begin
  Editor:=TfmEditor(fEditor);

  if PrepareForSave(fname, TRUE) then begin
    if not SaveInFormat(Editor.memo.Lines, Editor.TextFormat, fname) then
      DlgErrorSaveFile(fname);
  end;
end;
//------------------------------------------------------------------------------------------


////////////////////////////////////////////////////////////////////////////////////////////
//                               Constructor, destructor
////////////////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------------------
constructor TEditorFileHandler.Create(Editor: TObject);
begin
  fEditor:=Editor;
end;
//------------------------------------------------------------------------------------------

end.
