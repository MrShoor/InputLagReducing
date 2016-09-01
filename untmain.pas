unit untMain;

{$mode objfpc}{$H+}
{$ModeSwitch advancedrecords}

interface

uses
  LCLType, Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, ComCtrls, StdCtrls, avRes, avTypes, mutils, avTess, avContnrs,
  avCameraController, D3D11_JSB, DXGI_JSB, avContext_DX11;

type

  { TVertex }

  TVertex = packed record
    vsCoord   : TVec3;
    vsNormal  : TVec3;
    class function Layout: IDataLayout; static;
  end;
  IVertices = specialize IArray<TVertex>;
  TVertices = specialize TVerticesRec<TVertex>;

  { TInstance }

  TInstance = packed record
    aiPosition: TVec3;
    aiColor   : TVec4;
    class function Layout: IDataLayout; static;
  end;
  IInstances = specialize IArray<TInstance>;
  TInstances = specialize TVerticesRec<TInstance>;

  { TPanel }

  TPanel = class (ExtCtrls.TPanel)
  private
    FOnPaint: TNotifyEvent;
    procedure SetOnPaint(const AValue: TNotifyEvent);
  protected
    procedure PaintWindow(DC: HDC); override;
  public
    procedure EraseBackground(DC: HDC); override;
  public
    property OnPaint: TNotifyEvent read FOnPaint write SetOnPaint;
  end;

  { TfrmMain }

  TfrmMain = class(TForm)
    ApplicationProperties1: TApplicationProperties;
    ControlsPanel: TPanel;
    Label1: TLabel;
    rbDefault: TRadioButton;
    rbSetMaximumFrameLatency: TRadioButton;
    rbGenerateMips: TRadioButton;
    rbQueryEvent: TRadioButton;
    RenderPanel: TPanel;
    tbCycle: TTrackBar;
    procedure ApplicationProperties1Idle(Sender: TObject; var Done: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure rbRagResolveChange(Sender: TObject);
  private
    FCtx: TavMainRender;

    FShader: TavProgram;
    FBuffer, FInstances: TavVB;
    FFrame : TavFrameBuffer;

    FFPSTime   : Int64;
    FFPSCounter: Integer;
    procedure RenderScene(ASender: TObject);
  private
    FRawDevice: ID3D11Device;
    FRawDeviceContext: ID3D11DeviceContext;
    FRawSwapChain: IDXGISwapChain;
  private
    FSyncQuery: ID3D11Query;
    procedure SyncQueryWaitEvent;
    procedure SyncQuerySetEvent;
  private
    FSyncTex: ID3D11Texture2D;
    FSyncStaging: ID3D11Texture2D;
    FSyncView: ID3D11ShaderResourceView;
    procedure SyncTexWaitEvent;
    procedure SyncTexSetEvent;
  public

  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}
{$R 'shaders/shaders.rc'}

function GenCube: IVerticesData;
var vert: IVertices;
    v: TVertex;
begin
  vert := TVertices.Create;
  v.vsNormal := Vec(0,0,1);
  v.vsCoord := Vec(-1, -1, 1); vert.Add(v);
  v.vsCoord := Vec(-1,  1, 1); vert.Add(v);
  v.vsCoord := Vec( 1,  1, 1); vert.Add(v);
  v.vsCoord := Vec(-1, -1, 1); vert.Add(v);
  v.vsCoord := Vec( 1,  1, 1); vert.Add(v);
  v.vsCoord := Vec( 1, -1, 1); vert.Add(v);

  v.vsNormal := Vec(0,0,-1);
  v.vsCoord := Vec(-1, -1, -1); vert.Add(v);
  v.vsCoord := Vec( 1,  1, -1); vert.Add(v);
  v.vsCoord := Vec(-1,  1, -1); vert.Add(v);
  v.vsCoord := Vec(-1, -1, -1); vert.Add(v);
  v.vsCoord := Vec( 1, -1, -1); vert.Add(v);
  v.vsCoord := Vec( 1,  1, -1); vert.Add(v);

  v.vsNormal := Vec(0,1,0);
  v.vsCoord := Vec(-1, 1, -1); vert.Add(v);
  v.vsCoord := Vec( 1, 1,  1); vert.Add(v);
  v.vsCoord := Vec(-1, 1,  1); vert.Add(v);
  v.vsCoord := Vec(-1, 1, -1); vert.Add(v);
  v.vsCoord := Vec( 1, 1, -1); vert.Add(v);
  v.vsCoord := Vec( 1, 1,  1); vert.Add(v);

  v.vsNormal := Vec(0,-1,0);
  v.vsCoord := Vec(-1, -1, -1); vert.Add(v);
  v.vsCoord := Vec(-1, -1,  1); vert.Add(v);
  v.vsCoord := Vec( 1, -1,  1); vert.Add(v);
  v.vsCoord := Vec(-1, -1, -1); vert.Add(v);
  v.vsCoord := Vec( 1, -1,  1); vert.Add(v);
  v.vsCoord := Vec( 1, -1, -1); vert.Add(v);

  v.vsNormal := Vec(1,0,0);
  v.vsCoord := Vec(1, -1, -1); vert.Add(v);
  v.vsCoord := Vec(1, -1,  1); vert.Add(v);
  v.vsCoord := Vec(1,  1,  1); vert.Add(v);
  v.vsCoord := Vec(1, -1, -1); vert.Add(v);
  v.vsCoord := Vec(1,  1,  1); vert.Add(v);
  v.vsCoord := Vec(1,  1, -1); vert.Add(v);

  v.vsNormal := Vec(-1,0,0);
  v.vsCoord := Vec(-1, -1, -1); vert.Add(v);
  v.vsCoord := Vec(-1,  1,  1); vert.Add(v);
  v.vsCoord := Vec(-1, -1,  1); vert.Add(v);
  v.vsCoord := Vec(-1, -1, -1); vert.Add(v);
  v.vsCoord := Vec(-1,  1, -1); vert.Add(v);
  v.vsCoord := Vec(-1,  1,  1); vert.Add(v);

  Result := vert as IVerticesData;
end;

{ TInstance }

class function TInstance.Layout: IDataLayout;
begin
  Result := LB.Add('aiPosition', ctFloat, 3)
              .Add('aiColor', ctFloat, 4).Finish();
end;

{ TVertex }

class function TVertex.Layout: IDataLayout;
begin
  Result := LB.Add('vsCoord', ctFloat, 3)
              .Add('vsNormal', ctFloat, 3).Finish();
end;

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
  function GenCubeInstances(const ACounts: TVec3i): IVerticesData;
  var i, j, k: Integer;
      inst: TInstance;
      instances: IInstances;
      offset: TVec3;
  begin
    instances := TInstances.Create;
    offset := (-ACounts + Vec(1,1,1)) * 2;
    for i := 0 to ACounts.x - 1 do
      for j := 0 to ACounts.y - 1 do
        for k := 0 to ACounts.z - 1 do
        begin
          inst.aiPosition := Vec(i, j, k) * 4 + offset;
          inst.aiColor := Vec(Random, Random, Random, 0);
          instances.Add(inst);
        end;
    Result := instances as IVerticesData;
  end;
var rc: IRenderContext_DX11;
    cc: TavCameraController;
begin
  RenderPanel.OnPaint := @RenderScene;
  FCtx := TavMainRender.Create(nil);
  FCtx.Window := RenderPanel.Handle;
  FCtx.Init3D(apiDX11);
  FCtx.Camera.Eye := Vec(0,0,-200);

  FShader := TavProgram.Create(FCtx);
  FShader.Load('base', True);

  FBuffer := TavVB.Create(FCtx);
  FBuffer.CullMode := cmNone;
  FBuffer.PrimType := ptTriangles;
  FBuffer.Vertices := GenCube;

  FInstances := TavVB.Create(FCtx);
  FInstances.Vertices := GenCubeInstances(Vec(40, 40, 40));

  FFrame := Create_FrameBuffer(FCtx, [TTextureFormat.RGBA, TTextureFormat.D32f]);

  cc := TavCameraController.Create(FCtx);
  cc.CanRotate := True;

  rc := FCtx.Context as IRenderContext_DX11;
  FRawDevice := rc.GetDevice;
  FRawDeviceContext := rc.GetDeviceContext;
  FRawSwapChain := rc.GetSwapChain;
end;

procedure TfrmMain.ApplicationProperties1Idle(Sender: TObject; var Done: Boolean);
begin
  Done := Not Active;
  if Done then Exit;
  if Assigned(FCtx) then FCtx.InvalidateWindow;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FRawDeviceContext := nil;
  FRawDevice := nil;
  FRawSwapChain := nil;
  FreeAndNil(FCtx);
end;

procedure TfrmMain.rbRagResolveChange(Sender: TObject);
var dxgiDev: IDXGIDevice1;
begin
  if not Supports(FRawDevice, IDXGIDevice1, dxgiDev) then Exit;
  if rbSetMaximumFrameLatency.Checked then
    dxgiDev.SetMaximumFrameLatency(1)
  else
    dxgiDev.SetMaximumFrameLatency(0);
end;

procedure TfrmMain.RenderScene(ASender: TObject);
var
  i: Integer;
  currentTime, dTime: Int64;
begin
  if FCtx = nil then Exit;
  if FCtx.Bind then
  try
    if rbQueryEvent.Checked then SyncQueryWaitEvent;
    if rbGenerateMips.Checked then SyncTexWaitEvent;

    FCtx.Clear(Vec(0,0,0,0));
    FCtx.States.DepthTest := True;

    FFrame.FrameRect := RectI(0, 0, FCtx.WindowSize.x, FCtx.WindowSize.y);
    FFrame.Select();
    FFrame.Clear(0, Vec(0.0,0.2,0.4,0));
    FFrame.ClearDS(FCtx.Projection.DepthRange.y);

    FShader.Select;
    FShader.SetAttributes(FBuffer, nil, FInstances);
    FShader.SetUniform('CycleCount', tbCycle.Position*1.0);
    for i := 0 to FInstances.Vertices.VerticesCount - 1 do
      FShader.Draw(ptTriangles, cmBack, False, 1, 0, -1, 0, i);

    FFrame.BlitToWindow(0);

    if rbQueryEvent.Checked then SyncQuerySetEvent;
    if rbGenerateMips.Checked then SyncTexSetEvent;

    FRawSwapChain.Present(0,0);
  finally
    FCtx.Unbind;
  end;

  Inc(FFPSCounter);
  currentTime := FCtx.Time64;
  dTime := currentTime - FFPSTime;
  if dTime > 250 then
  begin
    Caption := 'FPS: '+IntToStr(Round(FFPSCounter*1000/dTime));
    FFPSTime := currentTime;
    FFPSCounter := 0;
  end;
end;

procedure TfrmMain.SyncQuerySetEvent;
begin
  if Assigned(FSyncQuery) then
    FRawDeviceContext._End(FSyncQuery);
end;

procedure TfrmMain.SyncTexWaitEvent;
var SrcSubRes, DstSubRes: LongWord;
    TexDesc: TD3D11_Texture2DDesc;
    ViewDesc: TD3D11_ShaderResourceViewDesc;
    Mapped: TD3D11_MappedSubresource;
begin
  if FSyncTex = nil then
  begin
    TexDesc.Width  := 2;
    TexDesc.Height := 2;
    TexDesc.MipLevels := 2;
    TexDesc.ArraySize := 1;
    TexDesc.Format := TDXGI_Format.DXGI_FORMAT_R8G8B8A8_UNORM;
    TexDesc.SampleDesc.Count := 1;
    TexDesc.SampleDesc.Quality := 0;
    TexDesc.Usage := TD3D11_Usage.D3D11_USAGE_DEFAULT;
    TexDesc.BindFlags := DWord(D3D11_BIND_SHADER_RESOURCE) or DWord(D3D11_BIND_RENDER_TARGET);
    TexDesc.CPUAccessFlags := 0;
    TexDesc.MiscFlags := DWord(D3D11_RESOURCE_MISC_GENERATE_MIPS);
    Check3DError(FRawDevice.CreateTexture2D(TexDesc, nil, FSyncTex));

    TexDesc.Width  := 1;
    TexDesc.Height := 1;
    TexDesc.MipLevels := 1;
    TexDesc.ArraySize := 1;
    TexDesc.Format := TDXGI_Format.DXGI_FORMAT_R8G8B8A8_UNORM;
    TexDesc.SampleDesc.Count := 1;
    TexDesc.SampleDesc.Quality := 0;
    TexDesc.Usage := TD3D11_Usage.D3D11_USAGE_STAGING;
    TexDesc.BindFlags := 0;
    TexDesc.CPUAccessFlags := DWord(D3D11_CPU_ACCESS_READ);
    TexDesc.MiscFlags := 0;
    Check3DError(FRawDevice.CreateTexture2D(TexDesc, nil, FSyncStaging));

    ViewDesc.Format := TDXGI_Format.DXGI_FORMAT_R8G8B8A8_UNORM;
    ViewDesc.ViewDimension := TD3D11_SRVDimension.D3D10_1_SRV_DIMENSION_TEXTURE2D;
    ViewDesc.Texture2D.MipLevels := 2;
    ViewDesc.Texture2D.MostDetailedMip := 0;
    Check3DError(FRawDevice.CreateShaderResourceView(FSyncTex, @ViewDesc, FSyncView));
  end
  else
  begin
    SrcSubRes := D3D11CalcSubresource(1, 0, 1);
    DstSubRes := D3D11CalcSubresource(0, 0, 1);
    FRawDeviceContext.CopySubresourceRegion(FSyncStaging, DstSubRes, 0, 0, 0, FSyncTex, SrcSubRes, nil);
    Check3DError(FRawDeviceContext.Map(FSyncStaging, DstSubRes, TD3D11_Map.D3D11_MAP_READ, 0, Mapped));
    FRawDeviceContext.Unmap(FSyncStaging, DstSubRes);
  end;
end;

procedure TfrmMain.SyncTexSetEvent;
begin
  if Assigned(FSyncView) then
    FRawDeviceContext.GenerateMips(FSyncView);
end;

procedure TfrmMain.SyncQueryWaitEvent;
var qDesc: TD3D11_QueryDesc;
    hRes: HRESULT;
    qResult: BOOL;
begin
  if FSyncQuery = nil then
  begin
    qDesc.MiscFlags := 0;
    qDesc.Query := D3D11_QUERY_EVENT;
    Check3DError(FRawDevice.CreateQuery(qDesc, FSyncQuery));
  end
  else
  begin
    repeat
      hRes := FRawDeviceContext.GetData(FSyncQuery, @qResult, SizeOf(qResult), 0);
      case hRes of
        S_OK: ;
        S_FALSE: qResult := False;
      else
        Check3DError(hRes);
      end;
    until qResult;
  end;
end;

{ TPanel }

procedure TPanel.SetOnPaint(const AValue: TNotifyEvent);
begin
  if FOnPaint = AValue then Exit;
  FOnPaint := AValue;
end;

procedure TPanel.PaintWindow(DC: HDC);
begin
  if Assigned(FOnPaint) then
    FOnPaint(Self)
  else
    inherited PaintWindow(DC);
end;

procedure TPanel.EraseBackground(DC: HDC);
begin
  if not Assigned(FOnPaint) then
    inherited EraseBackground(DC);
end;

end.

