// Copyright (c) 2009, ConTEXT Project Ltd
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// Neither the name of ConTEXT Project Ltd nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

unit fFileExplorer;

interface

{$I ConTEXT.inc}

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Menus, ImgList, ActnList, ComCtrls, StdCtrls, uSafeRegistry,
  ExtCtrls, Registry, uMultiLanguage, uCommon, DiscMon,
  fFileTree, TBX, TB2Item, TB2Dock, TB2Toolbar, TBXLists, TBXExtItems,
  VirtualTrees, VirtualExplorerTree, VirtualShellUtilities,
  JclFileUtils;

type
  TfmExplorer = class(TForm)
    pnDir: TPanel;
    labDir: TLabel;
    alExpl: TActionList;
    acLevelUp: TAction;
    acFilter: TAction;
    acOpen: TAction;
    acFileTree: TAction;
    TBXDock1: TTBXDock;
    tbFileExplorer: TTBXToolbar;
    TBXItem1: TTBXItem;
    TBXItem2: TTBXItem;
    TBXSeparatorItem1: TTBXSeparatorItem;
    TBXItem4: TTBXItem;
    TBXSeparatorItem2: TTBXSeparatorItem;
    TBXPopupMenu1: TTBXPopupMenu;
    TBXItem3: TTBXItem;
    TBXItem9: TTBXItem;
    TBXSeparatorItem3: TTBXSeparatorItem;
    TBXSubmenuItem4: TTBXSubmenuItem;
    TBItemContainer2: TTBItemContainer;
    TBXSubmenuItem5: TTBXSubmenuItem;
    labActiveFilter: TTBXLabelItem;
    TBXSeparatorItem4: TTBXSeparatorItem;
    strFilter: TTBXStringList;
    TBXSubmenuItem6: TTBXSubmenuItem;
    TBXItem10: TTBXItem;
    lv: TVirtualExplorerListview;
    procedure FormDeactivate(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure acDummyExecute(Sender: TObject);
    procedure acLevelUpExecute(Sender: TObject);
    procedure acFilterExecute(Sender: TObject);
    procedure alExplUpdate(Action: TBasicAction; var Handled: Boolean);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure DiscMonitorChange(Sender: TObject);
    procedure lvStartDrag(Sender: TObject; var DragObject: TDragObject);
    procedure lvPathChange(Sender: TObject; SelectedPath: String);
    procedure acOpenExecute(Sender: TObject);
    procedure acFileTreeExecute(Sender: TObject);
    procedure strFilterClick(Sender: TObject);
    procedure lvRootChange(Sender: TCustomVirtualExplorerTree);
    procedure lvEnumFolder(Sender: TCustomVirtualExplorerTree;
      Namespace: TNamespace; var AllowAsChild: Boolean);
    procedure lvDragOver(Sender: TBaseVirtualTree; Source: TObject;
      Shift: TShiftState; State: TDragState; Pt: TPoint; Mode: TDropMode;
      var Effect: Integer; var Accept: Boolean);
    procedure lvContextMenuAfterCmd(Sender: TCustomVirtualExplorerTree;
      Namespace: TNamespace; Verb: WideString; MenuItemID: Integer;
      Successful: Boolean);
    procedure lvContextMenuCmd(Sender: TCustomVirtualExplorerTree;
      Namespace: TNamespace; Verb: WideString; MenuItemID: Integer;
      var Handled: Boolean);
    procedure FormResize(Sender: TObject);
  private
    fFolderMonitor: TDiscMonitor;
    fConfigLoaded: boolean;
    FActiveFilter: string;
    fDecomposedFilters: string;
    FDirectory: string;
    FActive: boolean;
    fDirectoryContentChanged: boolean;
    fInitDirectory: string;
    fFilterList: TStringList;

    procedure SetActiveFilter(Value:string);
    procedure SetDirectory(Value:string);
    procedure SetActive(Value:boolean);

    procedure LoadConfig;
    procedure SaveConfig;
    function GetSelectedItems(IncludeFolders: boolean): TStringList;
    procedure StartDiscMonitor;
    procedure StopDiscMonitor;

    property  ActiveFilter :string  read FActiveFilter write SetActiveFilter;
  protected
    procedure WndProc(var Message: TMessage); override;
  public
    property Directory: string read FDirectory write SetDirectory;
    property Active: boolean read FActive write SetActive;
  end;

var
  fmExplorer: TfmExplorer;

implementation

uses
  fFilePane, fMain;

{$R *.DFM}

type
  TFileFilter = class
  private
    fExt: string;
    fFullFilter: string;
    fFilterName: string;
  public
    property Ext: string read fExt write fExt;
    property FilterName: string read fFilterName write fFilterName;
    property FullFilter: string read fFullFilter write fFullFilter;
  end;

type
  TMyBaseVirtualTree = class(TBaseVirtualTree);

////////////////////////////////////////////////////////////////////////////////////////////
//                                Property functions
////////////////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------------------
Function DirLabel(fileName : String; maxLen : Integer) : String;
const
  minLen = 12;
var
  strTmp, strNet : String;
  strLen, tmpLen, i, start, strNLen : Integer;
begin
  maxLen := (maxLen Div 4) - 18;
  if maxLen < 30
  then maxLen := 30;
  
  start  := 5;
  strLen := Length(fileName);
  tmpLen := AnsiPos('\', fileName) - 1;

  if fileName[tmpLen+2] = '\' then
  begin
    strNet := copy(fileName, 3, strLen);
    start  := AnsiPos('\', strNet) + 4;
  end;

  if (strLen>maxLen) and (maxLen>(start+minLen)) then
  begin

    if (tmpLen + start) >= maxLen then
      strTmp := copy(fileName, strLen-tmpLen, strLen)
    else
      strTmp := copy(fileName, strLen-maxLen+start, strLen);

    if (length(strTmp)-tmpLen) > 1
    then strTmp := copy(strTmp, AnsiPos('\', strTmp), strLen);

    strTmp := copy(fileName, 1, start-2) + '*' + strTmp;
    Result := strTmp;
  end
  else
    Result := fileName;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.SetActiveFilter(Value:string);
var
  FilterName: string;
begin
  if (FActiveFilter<>Value) then begin
    FActiveFilter:=Value;

    if DecomposeFileFilter(Value, FilterName, fDecomposedFilters) then begin
      if (Pos('*.*', fDecomposedFilters)=0) then begin
        fDecomposedFilters:=LowerCase(fDecomposedFilters);

        if (Length(fDecomposedFilters)>0) and (fDecomposedFilters[Length(fDecomposedFilters)]<>';') then
          fDecomposedFilters:=fDecomposedFilters+';';
      end else
        fDecomposedFilters:='';

      acFilter.Hint:='Filter: '+FilterName;
      labActiveFilter.Caption:=FilterName;
    end;

    lv.RebuildTree;
  end;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.SetDirectory(Value: string);
var
  dir_name: string;
begin
  if (FDirectory<>Value) then begin
    FDirectory:=Value;

    StartDiscMonitor;
    fFolderMonitor.Directory:=Value;

    SetLengthyOperation(TRUE);
    if (lv.RootFolderNamespace.NameForParsing<>Value) then
      lv.RootFolderCustomPath:=Value;
    SetLengthyOperation(FALSE);

    dir_name:=lv.RootFolderNamespace.NameParseAddress;
    labDir.Caption:=DirLabel(dir_name,labDir.Width);
    labDir.Hint:=dir_name;
  end;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.SetActive(Value:boolean);
begin
  if (FActive<>Value) then begin
    FActive:=Value;

    if Assigned(fFolderMonitor) then
      fFolderMonitor.Active:=Value;

    if Value and fDirectoryContentChanged then
      lv.RebuildTree;

    fDirectoryContentChanged:=FALSE;
  end;
end;
//------------------------------------------------------------------------------------------


////////////////////////////////////////////////////////////////////////////////////////////
//                                      Functions
////////////////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------------------
procedure TfmExplorer.LoadConfig;
var
  n: integer;
begin
  if not fConfigLoaded then begin
    with TSafeRegistry.Create do
      try
        OpenKey(CONTEXT_REG_KEY+'FileExplorer',TRUE);

        ActiveFilter:=ReadString('ActiveFilter', DEFAULT_ALL_FILES_FILTER);
        fInitDirectory:=ReadString('Dir', ApplicationDir);

        for n:=0 to lv.Header.Columns.Count-1 do
          lv.Header.Columns[n].Width:=ReadInteger('ColWidth'+IntToStr(n), lv.Header.Columns[n].Width);
    finally
      Free;
    end;

    fConfigLoaded:=TRUE;
  end;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.SaveConfig;
var
  n   :integer;
begin
  with TRegistry.Create do begin
    try
      if OpenKey(CONTEXT_REG_KEY+'FileExplorer',TRUE) then begin
        WriteString('Dir', Directory);
        WriteString('ActiveFilter', ActiveFilter);

        if Assigned(lv) then begin
          for n:=0 to lv.Header.Columns.Count-1 do
            WriteInteger('ColWidth'+IntToStr(n), lv.Header.Columns[n].Width);
        end;
      end;
    finally
      Free;
    end;
  end;
end;
//------------------------------------------------------------------------------------------
function TfmExplorer.GetSelectedItems(IncludeFolders: boolean): TStringList;
var
  i   :integer;
  str :TStringList;
  NamespaceArray: TNamespaceArray;
begin
  str:=TStringList.Create;

  NamespaceArray:=lv.SelectedToNamespaceArray;

  for i:=Low(NamespaceArray) to High(NamespaceArray) do begin
    if (IncludeFolders or (not NamespaceArray[i].Folder)) then
      str.Add(NamespaceArray[i].NameForParsing);
  end;

  result:=str;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.StartDiscMonitor;
begin
  if not Assigned(fFolderMonitor) then begin
    fFolderMonitor:=TDiscMonitor.Create(nil);
    with fFolderMonitor do begin
      if (FDirectory<>'') then
        Directory:=FDirectory
      else
        Directory:='c:\';
      Filters:=[moFileName, moDirName];
      SubTree:=FALSE;
      ChangeDelay:=2000;
      OnChange:=DiscMonitorChange;
      Active:=TRUE;
    end;
  end;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.StopDiscMonitor;
begin
  if Assigned(fFolderMonitor) then begin
    fFolderMonitor.Active:=FALSE;
    FreeAndNil(fFolderMonitor);
  end;
end;
//------------------------------------------------------------------------------------------


////////////////////////////////////////////////////////////////////////////////////////////
//                                     Actions
////////////////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------------------
procedure TfmExplorer.alExplUpdate(Action: TBasicAction;
  var Handled: Boolean);
begin
  acOpen.Enabled:=(lv.SelectedCount>0);
  acLevelUp.Enabled:=not lv.RootFolderNamespace.IsDesktop;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.acDummyExecute(Sender: TObject);
begin
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.acLevelUpExecute(Sender: TObject);
begin
  lv.BrowseToPrevLevel;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.acFilterExecute(Sender: TObject);
var
  i: integer;

  procedure AddFilter(Filter: string);
  var
    ff: TFileFilter;
    FilterName, FilterExt :string;
  begin
    if DecomposeFileFilter(Filter, FilterName, FilterExt) then begin
      ff:=TFileFilter.Create;
      ff.FullFilter:=Filter;
      ff.Ext:=FilterExt;
      ff.FilterName:=FilterName;
      fFilterList.AddObject(FilterName, ff);
    end;
  end;

begin
  if not Assigned(fFilterList) then begin
    fFilterList:=TStringList.Create;
    fFilterList.Sorted:=TRUE;

    for i:=0 to HIGHLIGHTERS_COUNT-1 do
      AddFilter(HighLighters[i].HL.DefaultFilter);

    AddFilter(DEFAULT_ALL_FILES_FILTER);

    strFilter.Strings.Assign(fFilterList);
  end;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.acOpenExecute(Sender: TObject);
var
  str :TStringList;
begin
  if (lv.SelectedCount=1) and (lv.SelectedToNamespaceArray[0].Folder) then begin
    Directory:=lv.SelectedToNamespaceArray[0].NameForParsing;
    EXIT;
  end;

  str:=GetSelectedItems(FALSE);
  fmMain.OpenMultipleFiles(str);
  str.Free;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.acFileTreeExecute(Sender: TObject);
var
  XY  :TPoint;
begin
  XY:=tbFileExplorer.ClientToScreen(Point(0,0));
  with TfmFileTree.Create(Application, FDirectory, lv) do begin
    SetBounds(XY.X, XY.Y+tbFileExplorer.Height, Width, Height);

    Show;

    if fmMain.dpFilePanel.Floating then
      FormStyle:=fsStayOnTop;
  end;
end;
//------------------------------------------------------------------------------------------


////////////////////////////////////////////////////////////////////////////////////////////
//                                    Drag'n'drop
////////////////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------------------
procedure TfmExplorer.lvStartDrag(Sender: TObject; var DragObject: TDragObject);
var
  str :TStringList;
begin
  with lv do begin
    if (SelectedCount>1) then
      DragCursor:=crMultiDrag
    else
      DragCursor:=crDrag;
  end;

  str:=GetSelectedItems(TRUE);
  TFilePanelDragFiles.Create(fmMain.FilePanel, lv, str);
  str.Free;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.lvDragOver(Sender: TBaseVirtualTree; Source: TObject;
  Shift: TShiftState; State: TDragState; Pt: TPoint; Mode: TDropMode;
  var Effect: Integer; var Accept: Boolean);
begin
  Accept:=FALSE;
end;
//------------------------------------------------------------------------------------------


////////////////////////////////////////////////////////////////////////////////////////////
//                                     Events
////////////////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------------------
procedure TfmExplorer.strFilterClick(Sender: TObject);
var
  n: integer;
begin
  n:=strFilter.ItemIndex;
  if (n<>-1) and Assigned(strFilter.Strings.Objects[n]) then begin
    ActiveFilter:=TFileFilter(strFilter.Strings.Objects[n]).FullFilter;
  end;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.lvPathChange(Sender: TObject; SelectedPath: String);
begin
  Directory:=PathAddSeparator(SelectedPath);
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.DiscMonitorChange(Sender: TObject);
begin
  if Active then
    lv.RebuildTree
  else
    fDirectoryContentChanged:=TRUE;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.lvRootChange(Sender: TCustomVirtualExplorerTree);
begin
  Directory:=lv.RootFolderNamespace.NameForParsing;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.lvEnumFolder(Sender: TCustomVirtualExplorerTree; Namespace: TNamespace; var AllowAsChild: Boolean);
var
  ext: string;
begin
  if (not Namespace.Folder) then begin
    ext:=LowerCase(ExtractFileExt(Namespace.NameNormal));
    AllowAsChild:=(Length(fDecomposedFilters)=0) or ((Length(ext)>0) and (Pos(ext+';', fDecomposedFilters)>0));
  end;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.lvContextMenuCmd(Sender: TCustomVirtualExplorerTree;
  Namespace: TNamespace; Verb: WideString; MenuItemID: Integer;
  var Handled: Boolean);
begin
  StopDiscMonitor;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.lvContextMenuAfterCmd(
  Sender: TCustomVirtualExplorerTree; Namespace: TNamespace;
  Verb: WideString; MenuItemID: Integer; Successful: Boolean);
begin
  StartDiscMonitor;
end;
//------------------------------------------------------------------------------------------


////////////////////////////////////////////////////////////////////////////////////////////
//                                    Form events
////////////////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------------------
procedure TfmExplorer.WndProc(var Message: TMessage);
begin
  case Message.Msg of
    WM_FILE_EXPLORER_LOAD_DIR:
      begin
        Directory:=fInitDirectory;
        lv.Active:=TRUE;
      end;
    else
      inherited;
  end;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.FormCreate(Sender: TObject);
begin
  acOpen.Caption:=mlStr(ML_FAV_OPEN,'&Open');
  acLevelUp.Caption:=mlStr(ML_EXPL_UPONELEVEL,'Up one level');
  acFilter.Caption:=mlStr(ML_EXPL_FILTER,'&Filter');

  acOpen.Hint:=mlStr(ML_EXPL_HINT_OPEN,'Open selected files');
  acLevelUp.Hint:=mlStr(ML_EXPL_UPONELEVEL,'Up one level');
  acFileTree.Hint:=mlStr(ML_EXPL_FILETREE,'Select directory');
  acFilter.Hint:=mlStr(ML_EXPL_FILTER,'Filter');

  with TMyBaseVirtualTree(lv) do begin
    DragType:=dtVCL;
    DragMode:=dmAutomatic;
  end;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.FormShow(Sender: TObject);
begin
  LoadConfig;
  PostMessage(Handle, WM_FILE_EXPLORER_LOAD_DIR, 0, 0);

  StartDiscMonitor;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.FormActivate(Sender: TObject);
begin
  alExpl.State := asNormal;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.FormDeactivate(Sender: TObject);
begin
  alExpl.State := asSuspended;
end;
//------------------------------------------------------------------------------------------
procedure TfmExplorer.FormDestroy(Sender: TObject);
begin
  if Assigned(fFolderMonitor) then
    FreeAndNil(fFolderMonitor);

  SaveConfig;

  if Assigned(fFilterList) then
    FreeAndNil(fFilterList);
end;
procedure TfmExplorer.FormResize(Sender: TObject);
begin
  labDir.Caption := DirLabel(lv.RootFolderNamespace.NameParseAddress,labDir.Width);
end;
//------------------------------------------------------------------------------------------
end.


