unit BitmapImage;

{
  Inno Setup
  Copyright (C) 1997-2004 Jordan Russell
  Portions by Martijn Laan
  For conditions of distribution and use, see LICENSE.TXT.

  A TImage-like component for bitmaps without the TPicture bloat

  $jrsoftware: issrc/Components/BitmapImage.pas,v 1.6 2009/03/23 14:57:40 mlaan Exp $
}

interface

{$I ..\Projects\VERSION.INC}

uses
  Windows, Controls, Graphics, Classes;

type
{$IFDEF IS_D12}
  TAlphaBitmap = TBitmap;
{$ELSE}
  {$DEFINE CUSTOM_BITMAP}
  TAlphaFormat = (afIgnored, afDefined, afPremultiplied);
  TAlphaBitmap = class(TBitmap)
  private
    FAlphaFormat: TAlphaFormat;
    procedure PreMultiplyAlpha;
  public
    procedure Assign(Source: TPersistent); override;
    procedure LoadFromStream(Stream: TStream); override;
    property AlphaFormat: TAlphaFormat read FAlphaFormat write FAlphaFormat;
  end;
{$ENDIF}

  TBitmapImage = class(TGraphicControl)
  private
    FAutoSize: Boolean;
    FBackColor: TColor;
    FBitmap: TAlphaBitmap;
    FCenter: Boolean;
    FReplaceColor: TColor;
    FReplaceWithColor: TColor;
    FStretch: Boolean;
    FStretchedBitmap: TBitmap;
    FStretchedBitmapValid: Boolean;
    procedure BitmapChanged(Sender: TObject);
    procedure SetBackColor(Value: TColor);
    procedure SetBitmap(Value: TBitmap);
    procedure SetCenter(Value: Boolean);
    procedure SetReplaceColor(Value: TColor);
    procedure SetReplaceWithColor(Value: TColor);
    procedure SetStretch(Value: Boolean);
    function GetBitmap: TBitmap;
  protected
    function GetPalette: HPALETTE; override;
    procedure Paint; override;
    procedure SetAutoSize(Value: Boolean); {$IFDEF UNICODE}override;{$ENDIF}
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Align;
    property AutoSize: Boolean read FAutoSize write SetAutoSize default False;
    property BackColor: TColor read FBackColor write SetBackColor default clBtnFace;
    property Center: Boolean read FCenter write SetCenter default False;
    property DragCursor;
    property DragMode;
    property Enabled;
    property ParentShowHint;
    property Bitmap: TBitmap read GetBitmap write SetBitmap;
    property PopupMenu;
    property ShowHint;
    property Stretch: Boolean read FStretch write SetStretch default False;
    property ReplaceColor: TColor read FReplaceColor write SetReplaceColor default clNone;
    property ReplaceWithColor: TColor read FReplaceWithColor write SetReplaceWithColor default clNone;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnStartDrag;
  end;

procedure Register;

implementation

{$IFNDEF IS_D6}
type
  TBlendFunction = record
    BlendOp: BYTE;
    BlendFlags: BYTE;
    SourceConstantAlpha: BYTE;
    AlphaFormat: BYTE;
  end;

const
  AC_SRC_OVER = $00;
  AC_SRC_ALPHA = $01;

function AlphaBlend(DC: HDC; p2, p3, p4, p5: Integer; DC6: HDC; p7, p8, p9,
  p10: Integer; p11: TBlendFunction): BOOL; stdcall; external 'msimg32.dll' name 'AlphaBlend';
{$ENDIF}

procedure Register;
begin
  RegisterComponents('JR', [TBitmapImage]);
end;

constructor TBitmapImage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csReplicatable];
  FBackColor := clBtnFace;
  FBitmap := TAlphaBitmap.Create;
  FBitmap.OnChange := BitmapChanged;
  FReplaceColor := clNone;
  FReplaceWithColor := clNone;
  FStretchedBitmap := TBitmap.Create;
  Height := 105;
  Width := 105;
end;

destructor TBitmapImage.Destroy;
begin
  FStretchedBitmap.Free;
  FBitmap.Free;
  inherited Destroy;
end;

procedure TBitmapImage.BitmapChanged(Sender: TObject);
begin
  FStretchedBitmapValid := False;
  if FAutoSize and (FBitmap.Width > 0) and (FBitmap.Height > 0) then
    SetBounds(Left, Top, FBitmap.Width, FBitmap.Height);
  if (FBitmap.Width >= Width) and (FBitmap.Height >= Height) then
    ControlStyle := ControlStyle + [csOpaque]
  else
    ControlStyle := ControlStyle - [csOpaque];
  Invalidate;
end;

procedure TBitmapImage.SetAutoSize(Value: Boolean);
begin
  FAutoSize := Value;
  BitmapChanged(Self);
end;

procedure TBitmapImage.SetBackColor(Value: TColor);
begin
  if FBackColor <> Value then begin
    FBackColor := Value;
    BitmapChanged(Self);
  end;
end;

procedure TBitmapImage.SetBitmap(Value: TBitmap);
begin
  FBitmap.Assign(Value);
end;

procedure TBitmapImage.SetCenter(Value: Boolean);
begin
  if FCenter <> Value then begin
    FCenter := Value;
    BitmapChanged(Self);
  end;
end;

procedure TBitmapImage.SetReplaceColor(Value: TColor);
begin
  if FReplaceColor <> Value then begin
    FReplaceColor := Value;
    BitmapChanged(Self);
  end;
end;

procedure TBitmapImage.SetReplaceWithColor(Value: TColor);
begin
  if FReplaceWithColor <> Value then begin
    FReplaceWithColor := Value;
    BitmapChanged(Self);
  end;
end;

procedure TBitmapImage.SetStretch(Value: Boolean);
begin
  if FStretch <> Value then begin
    FStretch := Value;
    FStretchedBitmap.Assign(nil);
    BitmapChanged(Self);
  end;
end;

function TBitmapImage.GetBitmap: TBitmap;
begin
  Result := FBitmap;
end;

function TBitmapImage.GetPalette: HPALETTE;
begin
  Result := FBitmap.Palette;
end;

procedure TBitmapImage.Paint;
const
  Bf: TBlendFunction =(
    BlendOp: AC_SRC_OVER;
    BlendFlags: 0;
    SourceConstantAlpha: 255;
    AlphaFormat: AC_SRC_ALPHA);

var
  R: TRect;
  Bmp: TBitmap;
  X, Y, W, H: Integer;
  Is32bit: Boolean;
begin
  with Canvas do begin
    R := ClientRect;
    Is32bit := (FBitmap.PixelFormat = pf32bit) and
      (FBitmap.AlphaFormat in [afDefined, afPremultiplied]);

    if Stretch then begin
      W := R.Right;
      H := R.Bottom;
      if not Is32bit then begin
        if not FStretchedBitmapValid or (FStretchedBitmap.Width <> W) or
           (FStretchedBitmap.Height <> H) then begin
          FStretchedBitmapValid := True;
          if (FBitmap.Width = W) and (FBitmap.Height = H) then
            FStretchedBitmap.Assign(FBitmap)
          else begin
            FStretchedBitmap.Assign(nil);
            FStretchedBitmap.Palette := CopyPalette(FBitmap.Palette);
            FStretchedBitmap.Width := W;
            FStretchedBitmap.Height := H;
            FStretchedBitmap.Canvas.StretchDraw(R, FBitmap);
          end;
        end;
        Bmp := FStretchedBitmap;
      end
      else
        Bmp := FBitmap;
    end else begin
      Bmp := FBitmap;
      W := Bmp.Width;
      H := Bmp.Height;
    end;

    if (FBackColor <> clNone) and (Bmp.Width < Width) or (Bmp.Height < Height) then begin
      Brush.Style := bsSolid;
      Brush.Color := FBackColor;
      FillRect(R);
    end;

    if csDesigning in ComponentState then begin
      Pen.Style := psDash;
      Brush.Style := bsClear;
      Rectangle(0, 0, Width, Height);
    end;

    if Center then begin
      X := R.Left + ((R.Right - R.Left) - W) div 2;
      if X < 0 then
        X := 0;
      Y := R.Top + ((R.Bottom - R.Top) - H) div 2;
      if Y < 0 then
        Y := 0;
    end else begin
      X := 0;
      Y := 0;
    end;

    if Is32bit then begin
      if AlphaBlend(Handle, X, Y, W, H, Bmp.Canvas.Handle, 0, 0, Bmp.Width, Bmp.Height, Bf) then
        Exit;
    end;
    if (FReplaceColor <> clNone) and (FReplaceWithColor <> clNone) then begin
      Brush.Color := FReplaceWithColor;
      BrushCopy(Rect(X, Y, X + W, Y + H), Bmp, Rect(0, 0, Bmp.Width, Bmp.Height), FReplaceColor);
    end else
      Draw(X, Y, Bmp);
  end;
end;

{$IFDEF CUSTOM_BITMAP}

{ TAlphaBitmap }

type
  // Some type that we know all Delphi supports and has correct width on all
  // platforms.
  NativeUInt = WPARAM;

procedure TAlphaBitmap.Assign(Source: TPersistent);
begin
  inherited;
  if Source is TAlphaBitmap then
    FAlphaFormat := TAlphaBitmap(Source).AlphaFormat;
end;

procedure TAlphaBitmap.LoadFromStream(Stream: TStream);
begin
  inherited;
  if (PixelFormat = pf32bit) and (FAlphaFormat = afDefined) then
    PreMultiplyAlpha;
end;

function BytesPerScanline(PixelsPerScanline, BitsPerPixel, Alignment: Longint): Longint;
begin
  Dec(Alignment);
  Result := ((PixelsPerScanline * BitsPerPixel) + Alignment) and not Alignment;
  Result := Result div 8;
end;

procedure TAlphaBitmap.PreMultiplyAlpha;
var
  Alpha: Word;
  ImageData, Limit: NativeUInt;
begin
  if (PixelFormat = pf32bit) then //Premultiply the alpha into the color
  begin
    Pointer(ImageData) := ScanLine[0];
    if ImageData = NativeUInt(nil) then
      Exit;
    Pointer(Limit) := ScanLine[Height - 1];
    // Is bottom up? (this can be distinguished by biHeight being positive but
    // since we don't have direct access to the headers we need to work around
    // that.
    if Limit < ImageData then
      ImageData := Limit;
    Limit := ImageData + NativeUInt(BytesPerScanline(Width, 32, 32) * Height);
    while ImageData < Limit do
    begin
      Alpha := PByte(ImageData + 3)^;
      PByte(ImageData)^ := MulDiv(PByte(ImageData)^, Alpha, 255);
      PByte(ImageData + 1)^ := MulDiv(PByte(ImageData + 1)^, Alpha, 255);
      PByte(ImageData + 2)^ := MulDiv(PByte(ImageData + 2)^, Alpha, 255);
      Inc(ImageData, 4);
    end;
  end;
end;

{$ENDIF}

end.
