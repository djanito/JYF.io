unit playerUnit;

interface

uses SDL2, SDL2_image, zoneUnit, SDL2_ttf, Sysutils;

const
  INITIAL_PLAYER_SIZE = 150;
  INITIAL_PLAYER_SCORE = round(sqr(INITIAL_PLAYER_SIZE)/400);
  INITIAL_PLAYER_MAGNITUDE = 60;
  INCREMENTAL_MAGNITUDE = 1.3;

type
  Player = record
      skin: PSDL_Texture;
      rect: TSDL_Rect;
      score: Integer;
      name: String;
      magnitude: Real;
      relX, relY: Integer;
      isAlive: Boolean;
      foodEaten: Integer;
      cellsEaten: Integer;
      topRank: Integer;
  end;

procedure InitializePlayer(renderer: PSDL_Renderer; var p: Player);
procedure TranslatePlayerToCenter(var p: Player);
procedure UpdatePlayer(var p: Player; newSize: Real);
procedure DeplacePlayer(var p: Player; mouseX, mouseY: Real);
procedure DrawDeathScreen(renderer: PSDL_Renderer; restartRect: TSDL_Rect; p: Player);

implementation

procedure InitializePlayer(renderer: PSDL_Renderer; var p: Player);
{ Initialise le joueur en lui assignant une image, des positions, un score, une vitesse }
begin
   Randomize;
   p.skin := IMG_LoadTexture(renderer, PChar('SKINS/' + IntToStr(Random(12)+1) + '.png'));
   if p.skin = nil then HALT;
   p.score := INITIAL_PLAYER_SCORE;
   p.rect.w := INITIAL_PLAYER_SIZE;
   p.rect.h := INITIAL_PLAYER_SIZE;
   p.rect.x := round(WIN_WIDTH/2 - p.rect.w/2);
   p.rect.y := round(WIN_HEIGHT/2 - p.rect.h/2);
   p.relX := random(ZONE_WIDTH - p.rect.w);
   p.relY := random(ZONE_HEIGHT - p.rect.h);
   p.magnitude := INITIAL_PLAYER_MAGNITUDE;
   p.isAlive := True;
   p.foodEaten := 0;
   p.cellsEaten := 0;
   p.topRank := -1;
end;

procedure UpdatePlayer(var p: Player; newSize: Real);
{ Modifie certains attributs du joueur quand il mange de la nourriture ou un ennemi }
begin
   p.rect.w := round(newSize);
   p.rect.h := p.rect.w;
   p.score := round(sqr(p.rect.w)/400);
   p.magnitude += INCREMENTAL_MAGNITUDE;
end;

procedure TranslatePlayerToCenter(var p: Player);
{ Recentre le joueur au milieu de l'écran à chaque tour pour donner l'illusion que le fond se déplace }
begin
   p.rect.x := round(WIN_WIDTH/2 - p.rect.w/2);
   p.rect.y := round(WIN_HEIGHT/2 - p.rect.h/2);
end;

procedure DeplacePlayer(var p: Player; mouseX, mouseY: Real);

{ Deplace le joueur à l'endroit de la souris selon 2 cas:
          - Si la souris est dans le rect du joueur: utilisez une formule classique de deplacement
          - Sinon, normalisé les petits deplacements
  On multiplie à la fin par la formule d'Agario de la vitesse de dépacement en fonction du score
  Enfin on regarde si le déplacement peut s'effectuer sans sortir de la zone de jeu
}

var
   vect: Vector;
   dx, dy, s: real;

begin
     // CALCULTATE VELOCITY, DX AND SPEED THANKS TO AGARIO EQUATION
     vect[0] := mouseX - WIN_WIDTH/2;
     vect[1] := mouseY - WIN_HEIGHT/2;

     if (abs(vect[0]) < p.rect.w/2) and (abs(vect[1]) < p.rect.h/2) then
        begin
          dx := vect[0] / p.magnitude;
          dy := vect[1] / p.magnitude;
        end
     else
        begin
          dx := vect[0]/sqrt(sqr(vect[0]) + sqr(vect[1]));
          dy := vect[1]/sqrt(sqr(vect[0]) + sqr(vect[1]));
        end;

     s := getSpeed(p.score); //35 * (1/sqrt(sqrt(100 * p.score)));

     CheckCollisionBorder(p.rect, p.relX, p.relY, dx * s, dy * s);
end;

procedure DrawDeathScreen(renderer: PSDL_Renderer; restartRect: TSDL_Rect; p: Player);

var surfaceTitle,
  surfaceFoodEaten, surfaceFoodEatenValue,
  surfaceCellsEaten, surfaceCellsEatenValue,
  surfaceHighestMass, surfaceHighestMassValue,
  surfaceTopRank, surfaceTopRankValue: PSDL_Surface;
    logo, bg, textureTitle,
      textureFoodEaten, textureFoodEatenValue,
      textureCellsEaten, textureCellsEatenValue,
      textureHighestMass, textureHighestMassValue,
      textureTopRank, textureTopRankValue, restartTexture: PSDL_Texture;
    rectTitle, logoRect, statRect,
      rectFoodEaten, rectFoodEatenValue,
      rectCellsEaten, rectCellsEatenValue,
      rectHighestMass, rectHighestMassValue,
      rectTopRank, rectTopRankValue: TSDL_Rect;
    fontTitle, fontSubtitle, fontValue: PTTF_Font;
    color: TSDL_Color;

begin
   SDL_RenderSetViewport(renderer, @DEATH_VIEWPORT);

   // draw logo
   logo := IMG_LoadTexture(renderer, PChar('logo.png'));
   logoRect.w := 400;
   logoRect.h := 199;
   logoRect.x := 0;
   logoRect.y := 0;
   SDL_RenderCopy(renderer, logo, nil, @logoRect);

   // draw background
   bg := IMG_LoadTexture(renderer, PChar('death.png'));
   statRect.x := round((DEATH_VIEWPORT.w - STATS_VIEWPORT_WIDTH)/2);
   statRect.y := DECALAGE_VIEWPORT;
   statRect.w := 365;
   statRect.h := 306;
   SDL_RenderCopy(renderer, bg, nil, @statRect);

   // draw final score
   fontTitle := TTF_OpenFont('FONTS\ARIALB.ttf', 30);
   fontSubtitle := TTF_OpenFont('FONTS\ARIAL.ttf', 16);
   fontValue := TTF_OpenFont('FONTS\ARIALB.ttf', 18);
   TTF_SetFontStyle(fontValue, TTF_STYLE_BOLD);

   color.r := 255; color.g := 255; color.b := 255;

   // TITLE
   rectTitle.w := 130;
   rectTitle.h := 35;
   rectTitle.x := round(DEATH_VIEWPORT.w/2 - rectTitle.w/2);
   rectTitle.y := DECALAGE_VIEWPORT + 20;

   surfaceTitle := TTF_RenderUTF8_Blended(fontTitle, PChar('Résultats'), color);
   textureTitle := SDL_CreateTextureFromSurface(renderer, surfaceTitle);

   // FOOD EATEN
   rectFoodEaten.w := 150;
   rectFoodEaten.h := 18;
   rectFoodEaten.x := round((DEATH_VIEWPORT_WIDTH - STATS_VIEWPORT_WIDTH)/2 + STATS_VIEWPORT_WIDTH/4 - rectFoodEaten.w/2);
   rectFoodEaten.y := DECALAGE_VIEWPORT + 80;

   surfaceFoodEaten := TTF_RenderUTF8_Blended(fontSubtitle, PChar('Nourritures mangées'), color);
   textureFoodEaten := SDL_CreateTextureFromSurface(renderer, surfaceFoodEaten);

   if (p.foodEaten < 10) then
      rectFoodEatenValue.w := 10
   else if (p.foodEaten < 100) then
      rectFoodEatenValue.w := 20
   else
      rectFoodEatenValue.w := 30;
   rectFoodEatenValue.h := 20;
   rectFoodEatenValue.x := round((DEATH_VIEWPORT_WIDTH - STATS_VIEWPORT_WIDTH)/2 + STATS_VIEWPORT_WIDTH/4 - rectFoodEatenValue.w/2);
   rectFoodEatenValue.y := rectFoodEaten.y + 30;

   surfaceFoodEatenValue := TTF_RenderUTF8_Blended(fontValue, PChar(IntToStr(p.foodEaten)), color);
   textureFoodEatenValue := SDL_CreateTextureFromSurface(renderer, surfaceFoodEatenValue);

   // CELLS EATEN
   rectCellsEaten.w := 125;
   rectCellsEaten.h := 18;
   rectCellsEaten.x := round((DEATH_VIEWPORT_WIDTH - STATS_VIEWPORT_WIDTH)/2 + STATS_VIEWPORT_WIDTH*3/4 - rectCellsEaten.w/2);
   rectCellsEaten.y := DECALAGE_VIEWPORT + 80;

   surfaceCellsEaten := TTF_RenderUTF8_Blended(fontSubtitle, PChar('Cellules mangées'), color);
   textureCellsEaten := SDL_CreateTextureFromSurface(renderer, surfaceCellsEaten);

   if (p.cellsEaten < 10) then
      rectCellsEatenValue.w := 10
   else if (p.cellsEaten < 100) then
      rectCellsEatenValue.w := 20
   else
      rectCellsEatenValue.w := 30;
   rectCellsEatenValue.h := 20;
   rectCellsEatenValue.x := round((DEATH_VIEWPORT_WIDTH - STATS_VIEWPORT_WIDTH)/2 + STATS_VIEWPORT_WIDTH* 3/4 - rectCellsEatenValue.w/2);
   rectCellsEatenValue.y := rectCellsEaten.y + 30;

   surfaceCellsEatenValue := TTF_RenderUTF8_Blended(fontValue, PChar(IntToStr(p.cellsEaten)), color);
   textureCellsEatenValue := SDL_CreateTextureFromSurface(renderer, surfaceCellsEatenValue);

   // HIGHEST SCORE
   rectHighestMass.w := 40;
   rectHighestMass.h := 18;
   rectHighestMass.x := round((DEATH_VIEWPORT_WIDTH - STATS_VIEWPORT_WIDTH)/2 + STATS_VIEWPORT_WIDTH/4 - rectHighestMass.w/2);
   rectHighestMass.y := DECALAGE_VIEWPORT + 150;

   surfaceHighestMass := TTF_RenderUTF8_Blended(fontSubtitle, PChar('Score'), color);
   textureHighestMass := SDL_CreateTextureFromSurface(renderer, surfaceHighestMass);

   if (p.score < 100) then
      rectHighestMassValue.w := 20
   else
      rectHighestMassValue.w := 30;
   rectHighestMassValue.h := 20;
   rectHighestMassValue.x := round((DEATH_VIEWPORT_WIDTH - STATS_VIEWPORT_WIDTH)/2 + STATS_VIEWPORT_WIDTH / 4 - rectHighestMassValue.w/2);
   rectHighestMassValue.y := rectHighestMass.y + 30;

   surfaceHighestMassValue := TTF_RenderUTF8_Blended(fontValue, PChar(IntToStr(p.score)), color);
   textureHighestMassValue := SDL_CreateTextureFromSurface(renderer, surfaceHighestMassValue);

   // TOP RANK
   rectTopRank.w := 95;
   rectTopRank.h := 18;
   rectTopRank.x := round((DEATH_VIEWPORT_WIDTH - STATS_VIEWPORT_WIDTH)/2 + STATS_VIEWPORT_WIDTH*3/4 - rectTopRank.w/2);
   rectTopRank.y := DECALAGE_VIEWPORT + 150;

   surfaceTopRank := TTF_RenderUTF8_Blended(fontSubtitle, PChar('Meilleur rang'), color);
   textureTopRank := SDL_CreateTextureFromSurface(renderer, surfaceTopRank);

   if (p.topRank < 10) then
      rectTopRankValue.w := 10
   else if (p.topRank < 100) then
      rectTopRankValue.w := 20
   else
      rectTopRankValue.w := 30;
   rectTopRankValue.h := 20;
   rectTopRankValue.x := round((DEATH_VIEWPORT_WIDTH - STATS_VIEWPORT_WIDTH)/2 + STATS_VIEWPORT_WIDTH* 3/4 - rectTopRankValue.w/2);
   rectTopRankValue.y := rectTopRank.y + 30;

   surfaceTopRankValue := TTF_RenderUTF8_Blended(fontValue, PChar(IntToStr(p.topRank)), color);
   textureTopRankValue := SDL_CreateTextureFromSurface(renderer, surfaceTopRankValue);

   // RESTART BUTTON
   restartTexture := IMG_LoadTexture(renderer, 'restart.png');

   // FREE ALL SURFACES
   SDL_FreeSurface(surfaceTitle);
   SDL_FreeSurface(surfaceFoodEaten);
   SDL_FreeSurface(surfaceFoodEatenValue);
   SDL_FreeSurface(surfaceCellsEaten);
   SDL_FreeSurface(surfaceCellsEatenValue);
   SDL_FreeSurface(surfaceHighestMass);
   SDL_FreeSurface(surfaceHighestMassValue);
   SDL_FreeSurface(surfaceTopRank);
   SDL_FreeSurface(surfaceTopRankValue);

   // DISPLAY ALL ELEMENTS
   SDL_RenderCopy(renderer, textureTitle, nil, @rectTitle);
   SDL_RenderCopy(renderer, textureFoodEaten, nil, @rectFoodEaten);
   SDL_RenderCopy(renderer, textureFoodEatenValue, nil, @rectFoodEatenValue);
   SDL_RenderCopy(renderer, textureCellsEaten, nil, @rectCellsEaten);
   SDL_RenderCopy(renderer, textureCellsEatenValue, nil, @rectCellsEatenValue);
   SDL_RenderCopy(renderer, textureHighestMass, nil, @rectHighestMass);
   SDL_RenderCopy(renderer, textureHighestMassValue, nil, @rectHighestMassValue);
   SDL_RenderCopy(renderer, textureTopRank, nil, @rectTopRank);
   SDL_RenderCopy(renderer, textureTopRankValue, nil, @rectTopRankValue);
   SDL_RenderCopy(renderer, restartTexture, nil, @restartRect);

   // FREE ALL TEXTURES
   SDL_DestroyTexture(textureTitle);
   SDL_DestroyTexture(textureFoodEaten);
   SDL_DestroyTexture(textureFoodEatenValue);
   SDL_DestroyTexture(textureCellsEaten);
   SDL_DestroyTexture(textureCellsEatenValue);
   SDL_DestroyTexture(textureHighestMass);
   SDL_DestroyTexture(textureHighestMassValue);
   SDL_DestroyTexture(textureTopRank);
   SDL_DestroyTexture(textureTopRankValue);
end;

end.


