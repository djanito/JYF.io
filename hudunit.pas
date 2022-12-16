unit hudUnit;

interface

uses SDL2, SDL2_ttf, zoneUnit, playerUnit, IAunit, Sysutils, StrUtils, math;

type
  Score = record
      surface: PSDL_Surface;
      texture: PSDL_Texture;
      rect: TSDL_Rect;
      font: PTTF_Font;
      score: Integer;
      color: TSDL_Color;
  end;

  Info = record
      score: Integer;
      name: String;
      texture: PSDL_Texture;
      rect: TSDL_Rect;
  end;

  LeaderboardText = record
      surface: PSDL_Surface;
      texture: PSDL_Texture;
      rect: TSDL_Rect;
      color: TSDL_Color;
  end;

  EntityInfos = Array[0..(NUMBER_IA+1)] of Info;
  TabLeaderboardText = Array of LeaderboardText;

const
  TEXT_SCORE = ' Score: ';
  W_LEADERBOARD_VIEWPORT = 180;
  H_LEADERBOARD_VIEWPORT = 65 + (NUMBER_IA+1) * 10 + (NUMBER_IA+1) * 15;

procedure InitializeScore(renderer: PSDL_Renderer; var s: Score);
procedure InitializeTabLeaderboardText(renderer: PSDL_Renderer; var tabText: TabLeaderboardText);
procedure UpdateScore(renderer: PSDL_Renderer; var s: Score; playerScore: Integer);
procedure DisplayLeaderboard(renderer: PSDL_Renderer; var p: Player; var tabText: TabLeaderboardText; tabInfos: EntityInfos);
procedure ActualizeInfos(var tabInfos: EntityInfos; p: Player; b: TabIA);

implementation

procedure InitializeScore(renderer: PSDL_Renderer; var s: Score);
{ Initialise l'affichage du score: texture, font, couleur }

begin
  s.font := TTF_OpenFont('FONTS\ARIALB.ttf', 16);
  TTF_SetFontStyle(s.font, TTF_STYLE_NORMAL);

  s.rect.w := 80;
  s.rect.h := 20;
  s.rect.x := 8;
  s.rect.y := WIN_HEIGHT - s.rect.h - 5;

  s.color.r := 255; s.color.g := 255; s.color.b := 255;

  s.surface := TTF_RenderUTF8_Blended(s.font, PChar(TEXT_SCORE + IntToStr(INITIAL_PLAYER_SCORE)), s.color);
  s.texture := SDL_CreateTextureFromSurface(renderer, s.surface);
  SDL_FreeSurface(s.surface);
end;

procedure InitializeTabLeaderboardText(renderer: PSDL_Renderer; var tabText: TabLeaderboardText);
{ Initialise les surfaces de tout le texte constituant le leaderboard: Titre & joueurs }

var
   i: Integer;
   font: PTTF_Font;
   color: TSDL_Color;

begin
  // DEFINE COLOR AND FONT
  color.r := 255; color.g := 255; color.b := 255;
  font := TTF_OpenFont('FONTS\ARIALB.ttf', 23);

  // SET LEADERBOARD NUMBER OF TEXTS (first +1 for player and second +1 for leaderboard title text)
  setlength(tabText, NUMBER_IA+1+1);

  // DEFINE LEADERBOARD TEXT
  for i := 0 to High(tabText) do
    begin
      if (i = 0) then
         begin
           // DEFINE LEADERBOARD TEXT
           tabText[i].rect.h := 28;
           tabText[i].rect.y := 10;
           tabText[i].surface := TTF_RenderUTF8_Blended(font, 'Leaderboard', color);
           tabText[i].texture := SDL_CreateTextureFromSurface(renderer, tabText[0].surface);
         end
      else
         begin
           tabText[i].rect.h := 20;
           tabText[i].rect.y := 20 + i * 10 + i * 15;
         end;

      tabText[i].rect.w := 140;
      tabText[i].rect.x := round(W_LEADERBOARD_VIEWPORT/2 - tabText[i].rect.w/2);;
      tabText[i].color := color;
    end;
end;

procedure UpdateScore(renderer: PSDL_Renderer; var s: Score; playerScore: Integer);
{ Actualise le text du score lorsque celui ci change }
begin
  SDL_DestroyTexture(s.texture);
  s.surface := TTF_RenderUTF8_Blended(s.font, PChar(TEXT_SCORE + IntToStr(playerScore) + ' '), s.color);
  s.texture := SDL_CreateTextureFromSurface(renderer, s.surface);
  SDL_FreeSurface(s.surface);
end;

procedure DisplayLeaderboard(renderer: PSDL_Renderer; var p: Player; var tabText: TabLeaderboardText; tabInfos: EntityInfos);
{ Associe les bonnes infos du leaderboard aux bonnes textures/surface et affiche à l'écran le titre du leaderboard et les infos: du score le plus grand au plus petit }

var i : Integer;
    font: PTTF_Font;

begin
  // SET LEADERBOARD VIEWPORT COLOR
  SDL_SetRenderDrawColor(renderer, 47, 53, 66, 90);
  SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
  SDL_RenderFillRect(renderer, nil);

  // DISPLAY LEADERBOARD INFOS (MAX 10 VALUES)
  font := TTF_OpenFont('FONTS\ARIALB.ttf', 17);
  for i:= 0 to Min(High(tabText),10) do
    begin
      // ADD TEXTURE & SURFACE FOR ALL INFOS OF LEADERBOARD EXCEPTED TITLE
      if (i >= 1) then
         begin
           if (tabInfos[i].name = p.name) then
              if (i > p.topRank) then p.topRank := i;
           tabText[i].surface := TTF_RenderUTF8_Blended(font, PChar(intToStr(i) + '. ' + tabInfos[i].name + DupeString(' ', 21 - Length(tabInfos[i].name))), tabText[i].color);
           tabText[i].texture := SDL_CreateTextureFromSurface(renderer, tabText[i].surface);
           SDL_FreeSurface(tabText[i].surface);
         end;
      SDL_RenderCopy(renderer, tabText[i].texture, nil, @tabText[i].rect);
      if (i >= 1) then SDL_DestroyTexture(tabText[i].texture);
    end;
end;

procedure SortLeaderboardByScore(var tabInfos: EntityInfos);
{ Permet de trier l'ensemble des entités par score croissant en stockant le nom, la texture, le rect et le score dans un tableau }

var
   i, j, s: Integer;
   n: String;
   t: PSDL_Texture;
   r: TSDL_Rect;

begin
  // Insertion Sort Algorithm: best for very small number of value
   for i := 2 to High(tabInfos) do
     begin
       s := tabInfos[i].score;
       n := tabInfos[i].name;
       t := tabInfos[i].texture;
       r := tabInfos[i].rect;
       j := i;
       while ((j > 1) and  (tabInfos[j-1].score < s)) do
          begin
            tabInfos[j].score := tabInfos[j-1].score;
            tabInfos[j].name := tabInfos[j-1].name;
            tabInfos[j].texture := tabInfos[j-1].texture;
            tabInfos[j].rect := tabInfos[j-1].rect;
  	    j -= 1;
  	  end;

  	  tabInfos[j].score := s;
          tabInfos[j].name := n;
          tabInfos[j].texture := t;
          tabInfos[j].rect := r;
     end;

end;

procedure ActualizeInfos(var tabInfos: EntityInfos; p: Player; b: TabIA);
{ Actualise en permanence les données du leadeboard en triant les données des entités }

var i: Integer;

begin
   for i := 0 to High(tabInfos)-1 do
     begin
       tabInfos[i].score := b[i].score;
       tabInfos[i].name := b[i].name;
       tabInfos[i].texture := b[i].skin;
       tabInfos[i].rect := b[i].rect;
     end;

   if (p.isAlive) then
      begin
        tabInfos[High(tabInfos)].score := p.score;
        tabInfos[High(tabInfos)].name := p.name;
        tabInfos[High(tabInfos)].texture := p.skin;
        tabInfos[High(tabInfos)].rect := p.rect;
      end
   else
      // IF PLAYER IS DEAD
      tabInfos[High(tabInfos)].texture := nil;

     SortLeaderboardByScore(tabInfos);
end;

end.


