unit zoneUnit;

interface

uses SDL2, SDL2_image, math;

const
  ZONE_WIDTH = 1750;
  ZONE_HEIGHT = 1750;

  WIN_WIDTH = 1280;
  WIN_HEIGHT = 720;
  MAIN_VIEWPORT: TSDL_Rect = (x: 0; y: 0; w: WIN_WIDTH; h: WIN_HEIGHT);

  MENU_VIEWPORT: TSDL_Rect = (x: 0; y: 0; w: WIN_WIDTH; h: WIN_HEIGHT);

  DEATH_VIEWPORT_WIDTH = 400;
  DEATH_VIEWPORT_HEIGHT = 600;
  DEATH_VIEWPORT: TSDL_Rect = (x: round(WIN_WIDTH/2 - DEATH_VIEWPORT_WIDTH/2); y: round(WIN_HEIGHT/2 - DEATH_VIEWPORT_HEIGHT/2); w: DEATH_VIEWPORT_WIDTH; h: DEATH_VIEWPORT_HEIGHT);

  STATS_VIEWPORT_WIDTH = 365;
  STATS_VIEWPORT_HEIGHT = 306;
  DECALAGE_VIEWPORT = 235;

  DETECTION_CIRCLE_RADIUS = 300;


type
  Zone = record
      rect: TSDL_Rect;
      texture: PSDL_Texture;
  end;

  Vector = array [0..1] of Real;

  // TAB IN WHICH EACH ELEMENT IS 2 VECTORS LIKE [(x1,y1), (x2,y2)]
  TabCollidePoints = array of array[0..1] of TSDL_Point;
  SetofPoints = Array of TSDL_Point;

procedure InitializeZone(renderer: PSDL_Renderer; var z: Zone; diffPX, diffPY: Integer);
procedure TranslateZone(var z: Zone; pRect: TSDL_Rect);
procedure CheckCollisionBorder(var rect: TSDL_Rect; var relX: Integer; var relY: Integer; dXs, dYs: Real);
function getSpeed(score: Integer): Real;

implementation

procedure InitializeZone(renderer: PSDL_Renderer; var z: Zone; diffPX, diffPY: Integer);
{ Initialise le plateau de jeu avec une texture et une taille }
begin
   z.rect.x := - diffPX;
   z.rect.y := - diffPY;
   z.rect.w := ZONE_WIDTH;
   z.rect.h := ZONE_HEIGHT;
   z.texture := IMG_LoadTexture(renderer, 'bg.png');
end;

procedure TranslateZone(var z: Zone; pRect: TSDL_Rect);
{ Déplace la zone de jeu dans la direction opposé à celle du joueur }
begin
     z.rect.x += round((WIN_WIDTH - pRect.w)/2) - pRect.x;
     z.rect.y += round((WIN_HEIGHT - pRect.h)/2) - pRect.y;
end;

procedure CheckCollisionBorder(var rect: TSDL_Rect; var relX: Integer; var relY: Integer; dXs, dYs: Real);
{ Detecte les collisions avec les bords du plateau:
   - si le déplacement (dXs ou dYs) fait sortir le joueur du plateau: on place le joueur à la limite de la zone
   - sinon on ne fait rien }
var increaseX, increaseY: Real;

begin
     // CHECK BORDER COLLISION
     if (relX + dXs < 0) then
        increaseX := -relX
     else if (relX + rect.w + dXs > ZONE_WIDTH) then
        increaseX := ZONE_WIDTH - rect.w - relX
     else
         increaseX := dXs;

     if (relY + dYs < 0) then
        increaseY := -relY
     else if (relY + rect.h + dYs > ZONE_HEIGHT) then
        increaseY := ZONE_HEIGHT - rect.h - relY
     else
         increaseY := dYs;

     rect.x += round(increaseX);
     rect.y += round(increaseY);

     relX += round(increaseX);
     relY += round(increaseY);
end;

function getSpeed(score: Integer): Real;
{ Retourne l'équation de vitesse des entités du jeu en fonction de leur score }
begin
     if (score <> 0) then
        getSpeed := 18/Power(score, 0.3);
end;

end.

