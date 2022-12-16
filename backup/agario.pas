program test;

uses SDL2, SDL2_image, SDL2_ttf, sysutils, nourritureUnit, playerUnit, zoneUnit, hudUnit, IAunit, math, StrUtils;

var
  window: PSDL_Window;
  sdlRenderer: PSDL_Renderer;
  sdlEvent: PSDL_Event;
  exitloop: boolean = false;
  isMouseWindow: boolean = true;
  mouseX: Integer;

  isInGame: boolean = False;
  playerName: String = '';

  bTextureIndex, nTextureIndex, infoIndex: Integer;
  next_time: Integer;

  z: Zone;
  n: TabNourriture;
  p: Player;
  s: Score;
  b: TabIA;

  tabInfos: EntityInfos;
  texteLeaderboard : TabLeaderboardText;
  LeaderboardViewport: TSDL_Rect = (x: WIN_WIDTH-W_LEADERBOARD_VIEWPORT - 5;   y:   5; w: W_LEADERBOARD_VIEWPORT; h: H_LEADERBOARD_VIEWPORT);

const
  TICK_INTERVAL = 20;
  RESTART_RECT: TSDL_Rect = (x: round(DEATH_VIEWPORT_WIDTH/2 - 297/2); y: 240 + DECALAGE_VIEWPORT; w: 297; h:46);
  START_RECT: TSDL_Rect = (x: round(WIN_WIDTH/2 - 320/2); y: 520; w: 320; h:52);
  NAME_INPUT_TEXT = 'Saisissez votre pseudo';

procedure DetectNourritureCollide();
{ Update les entités lorsqu'elles mangent de la nourriture: augmentation du score et donc de la taille }

var botIndex: Integer;

begin
  if (isNourritureCollide(n, p.rect, p)) then
     begin
       p.score += 1;
       p.foodEaten += 1;
       p.rect.w := round(sqrt(400*p.score));
       p.rect.h := p.rect.w;
       p.magnitude += INCREMENTAL_MAGNITUDE;
     end;

  for botIndex:= 0 to High(b) do
    if (isNourritureCollide(n, b[botIndex].rect, p)) then
       begin
         b[botIndex].score += 1;
         b[botIndex].rect.w := round(sqrt(400 * b[botIndex].score));
         b[botIndex].rect.h := b[botIndex].rect.w;
       end;
end;

procedure DetectEntityCollide();
{ Permet de detecter les collisions entre IA/Joueur ou IA/IA grâce à une nested loop et grâce à un calcul de distance:
  - si l'entité est plus petite, on la regénère autre part sur la zone de jeu en réinitialisant ses attributs
  - sinon, on augmente sa taille et son score relativement à l'entité mangée
Une entité doit être 11% plus grande qu'une autre pour la manger.
Si leur différence de taille est < à 11%, elles ne peuvent pas se manger.
}

var
  i,j, diffX, diffY, sizeDiff: integer;
  distance, sumSurface: Real;
  rect: TSDL_Rect;

begin
  // NESTED LOOP
  for i := 0 to High(b) do
    for j:= i+1 to High(b) do
      begin

        if (p.isAlive) then
           begin
             if (i = 0) then
                rect := p.rect
             else
                rect := b[i].rect;
           end
        else
           if (i <> 0) then
              rect := b[i].rect;

        diffX := rect.x - b[j].rect.x;
        diffY := rect.y - b[j].rect.y;
        sizeDiff := rect.w - b[j].rect.w;

       // PRE-VERIFICATION COLLIDE
       if (abs(diffX) <= abs(sizeDiff)) and (abs(diffY) <= abs(sizeDiff)) then
          begin
            distance := sqrt(sqr((b[j].rect.x + b[j].rect.w/2)- (rect.x + rect.w/2)) + sqr((b[j].rect.y + b[j].rect.h/2) - (rect.y + rect.h/2)));
            if (trunc(distance) <= trunc(abs(rect.w/2 - b[j].rect.w/2))) then
               begin
                 // IF FIRST ELEMENT IS BIGGER THAN SECOND
                 if (0.89 * b[j].rect.w >= rect.w) then
                    begin
                      sumSurface := Pi * sqr(b[j].rect.w/2) + Pi * sqr(0.382 * rect.w/2);

                      if (i = 0) then
                         begin
                           p.isAlive := False;
                         end
                      else
                         RegenerateIAOnDeath(b[i], (p.relX - p.rect.x), (p.relY - p.rect.y));

                      UpdateIA(b[j], 2 * sqrt(sumSurface/Pi));
                    end
                 else if (0.89 * rect.w >= b[j].rect.w) then
                    begin
                      sumSurface := Pi * sqr(0.382 * b[j].rect.w/2) + Pi * sqr(rect.w/2);

                      if (i = 0) then
                         begin
                           p.cellsEaten += 1;
                           UpdatePlayer(p, 2 * sqrt(sumSurface/Pi));
                         end
                      else
                         UpdateIA(b[i], 2 * sqrt(sumSurface/Pi));

                      RegenerateIAOnDeath(b[j], (p.relX - p.rect.x), (p.relY - p.rect.y));
                    end;
               end;
          end;
      end;
end;

procedure Initialize();
begin
  next_time := 0;
  // Initialize player - nourriture - zone - score HUD
  InitializePlayer(sdlRenderer, p);
  GenerateIA(sdlRenderer, b, p.relX - p.rect.x, p.relY - p.rect.y);
  GenerateNourriture(sdlRenderer, n, p.relX - p.rect.x, p.relY - p.rect.y);
  InitializeZone(sdlRenderer, z, p.relX - p.rect.x, p.relY - p.rect.y);
  InitializeScore(sdlRenderer, s);
  InitializeTabLeaderboardText(sdlRenderer, texteLeaderboard);
end;

function timeLeft(): Integer;

var now: Integer;

begin
  now := SDL_GetTicks();

  if(next_time <= now) then
     timeLeft := 0
  else
     timeLeft := next_time - now;

end;

procedure DrawMenu();

var
  logo, startTexture, nameTexture, menu: PSDL_Texture;
  nameSurface: PSDL_Surface;
  logoRect, nameRect, menuRect: TSDL_Rect;
  font: PTTF_Font;
  color: TSDL_Color;

begin
  SDL_RenderSetViewport(sdlRenderer, @MAIN_VIEWPORT);

  // define attributs
  font := TTF_OpenFont('FONTS\ARIAL.ttf', 26);
  color.r := 255; color.g := 255; color.b := 255;

  // draw logo
  logo := IMG_LoadTexture(sdlRenderer, PChar('logo.png'));
  logoRect.w := 400;
  logoRect.h := 199;
  logoRect.x := round(WIN_WIDTH/2 - logoRect.w/2);
  logoRect.y := 100;

  // draw background
   menu := IMG_LoadTexture(sdlRenderer, PChar('menu.png'));
   menuRect.w := 365;
   menuRect.h := 140;
   menuRect.x := round(WIN_WIDTH/2 - menuRect.w/2);
   menuRect.y := logoRect.y + logoRect.h + 150;

  // NAME INPUT
   nameRect.w := 280;
   nameRect.h := 30;
   nameRect.x := round(WIN_WIDTH/2 - nameRect.w/2);
   nameRect.y := menuRect.y + 20;

   if (Length(playerName) = 0) then
      nameSurface := TTF_RenderUTF8_Blended(font, PChar(NAME_INPUT_TEXT), color)
   else
      nameSurface := TTF_RenderUTF8_Blended(font, PChar(DupeString(' ', 15 - round(length(playerName)/2)) + playerName + DupeString(' ', 15 - round(length(playerName)/2))), color);
   nameTexture := SDL_CreateTextureFromSurface(sdlRenderer, nameSurface);

   // RESTART BUTTON
   startTexture := IMG_LoadTexture(sdlRenderer, 'play.png');

   // DRAW TO SCREEN
   SDL_RenderCopy(sdlRenderer, menu, nil, @menuRect);
   SDL_RenderCopy(sdlRenderer, logo, nil, @logoRect);
   SDL_RenderCopy(sdlRenderer, startTexture, nil, @START_RECT);
   SDL_RenderCopy(sdlRenderer, nameTexture, nil, @nameRect);

   // RELEASE MEMORY
   SDL_FreeSurface(nameSurface);
   SDL_DestroyTexture(menu);
   SDL_DestroyTexture(logo);
   SDL_DestroyTexture(startTexture);
   SDL_DestroyTexture(nameTexture);
end;


begin
  // Initilization of video subsystem
  if SDL_Init(SDL_INIT_VIDEO) < 0 then Halt;

  // Setup window
  window := SDL_CreateWindow('JYF.io', 50, 50, WIN_WIDTH, WIN_HEIGHT, SDL_WINDOW_SHOWN);
  SDL_SetWindowIcon(window, SDL_LoadBMP('icon.bmp'));
  sdlRenderer := SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

  if sdlRenderer = nil then Halt;
  if window = nil then Halt;
  if TTF_Init = -1 then Halt;

  // SET LEADERBOARD VIEWPORT HEIGHT
  LeaderboardViewport.h := 65 + min(NUMBER_IA+1, 10) * 10 + min(NUMBER_IA+1, 10) * 15;

  Initialize();

  next_time := SDL_GetTicks() + TICK_INTERVAL;
  // gestion event
  new(sdlEvent);
  while exitloop = false do
    begin
      while SDL_PollEvent(sdlEvent) = 1 do
          case sdlEvent^.type_ of
            SDL_WINDOWEVENT:
              case sdlEvent^.window.event of
                       SDL_WINDOWEVENT_CLOSE: exitloop := true;
                       SDL_WINDOWEVENT_ENTER: isMouseWindow := true;
                       SDL_WINDOWEVENT_LEAVE: isMouseWindow := false;
              end;
            SDL_KEYDOWN:
              begin
               if (isInGame = False) then
                  // NAME INPUT SYSTEM
                  begin
                         if (sdlEvent^.key.keysym.scancode = 42) then
                            // IF REMOVE KEY PRESS
                            SetLength(playerName, Length(playerName) - 1) // remove last char
                         else if (Length(playerName) < 20) then // 20 is max length for name
                            begin
                              if (sdlEvent^.key.keysym.scancode = 44) then
                                 // IF SPACE KEY PRESS
                                 playerName += ' ' // add space to the end
                              else
                                 playerName += SDL_GetKeyName(sdlEvent^.key.keysym.sym);
                            end;
                  end;
              end;
            SDL_MOUSEBUTTONDOWN:
              begin
               if (p.isAlive = False) then
                  if (sdlEvent^.button.x >= DEATH_VIEWPORT.x + RESTART_RECT.x) and (sdlEvent^.button.x <= DEATH_VIEWPORT.x + RESTART_RECT.x + RESTART_RECT.w) and (sdlEvent^.button.y >= DEATH_VIEWPORT.Y + RESTART_RECT.y) and (sdlEvent^.button.y <= DEATH_VIEWPORT.y + RESTART_RECT.y + RESTART_RECT.h) then
                     Initialize();
               if (isInGame = False) then
                  if (Length(playerName) > 0) then // CHECK IF NAME ISN'T EMPTY
                     if (sdlEvent^.button.x >= START_RECT.x) and (sdlEvent^.button.x <= START_RECT.x + START_RECT.w) and (sdlEvent^.button.y >= START_RECT.y) and (sdlEvent^.button.y <= START_RECT.y + START_RECT.h) then
                        begin
                          playerName := LowerCase(playerName); // lowercase
                          playerName[1] := UpCase(playerName[1]); // Capitalize
                          p.name := playerName;
                          isInGame := True;
                        end;
              end;
          end;

      if isMouseWindow then
         mouseX := sdlEvent^.motion.x;



      // ------------ TRANSLATION PART ----------
      if (isIngame = True) then
         begin
           if (p.isAlive) then
              DeplacePlayer(p, mouseX, sdlEvent^.motion.y);
           TranslateNourriture(n, p.rect);
           TranslateZone(z, p.rect);
           TranslateIA(b, p);
           TranslatePlayerToCenter(p);
         end;

      // ------------ ENTITY COLLIDE DETECTION PART ----------
      if (isInGame = True) then
         begin
           DetectNourritureCollide;
           DetectEntityCollide;
         end;

      // ------------ DRAW MAIN PART ----------
      SDL_SetRenderDrawColor(sdlRenderer, 17, 17, 17, SDL_ALPHA_OPAQUE);
      SDL_RenderClear(sdlRenderer);

      SDL_RenderSetViewport(sdlRenderer, @MAIN_VIEWPORT);

      // DISPLAY: ZONE - FOOD - IA - PLAYER - SCORE
      SDL_RenderCopy(sdlRenderer, z.texture, nil, @z.rect);
      DisplayNourriture(sdlRenderer, n);


      if (isInGame = True) then
         begin
           // draw player & IA by decreasing size
           ActualizeInfos(tabInfos, p , b);
           for infoIndex := High(tabInfos) downto 1 do
             if (tabInfos[infoIndex].texture <> nil) then // IF PLAYER IS DEAD: DON'T DRAW ITS TEXTURE
                SDL_RenderCopy(sdlRenderer, tabInfos[infoIndex].texture, nil, @tabInfos[infoIndex].rect);

           // UPDATE & DRAW SCORE
           UpdateScore(sdlRenderer, s, p.score);
           SDL_SetRenderDrawBlendMode(sdlRenderer, SDL_BLENDMODE_BLEND);
           SDL_SetRenderDrawColor(sdlRenderer, 47, 53, 66, 90);
           SDL_RenderFillRect(sdlRenderer, @s.rect);
           SDL_RenderCopy(sdlRenderer, s.texture, nil, @s.rect);

           // ------------ IA DECISION MAKING PART ----------
           TakeIADecision(b, p, n, sdlRenderer);

           // ------------ LEADERBOARD PART ----------
           SDL_RenderSetViewport(sdlRenderer, @LeaderboardViewport);
           DisplayLeaderboard(sdlRenderer, p, texteLeaderboard, tabInfos);

         end;



      // ------------ MENU VIEWPORT AT BEGINING----------
      if (isInGame = False) then DrawMenu();

      // ------------ DEATH VIEWPORT WHEN PLAYER IS EAT ----------
      if (p.isAlive = False) then DrawDeathScreen(sdlRenderer, RESTART_RECT, p);

      // ------------ DRAW TO SCREEN AND DELAY ----------
      SDL_RenderPresent(sdlRenderer);

      {
      if (isInGame) then
         begin
           SDL_Delay(timeLeft());
           next_time += TICK_INTERVAL;
         end
      else if (isInGame = False) or (p.isAlive = False) then
         begin
           writeln('true');
           SDL_Delay(round(1000/120));
         end;
         }
      SDL_Delay(round(1000/120));
    end;

  // clear events
  dispose(sdlEvent);

  // clear memory: font & texture
  TTF_CloseFont(s.font);
  TTF_Quit;
  IMG_Quit;

  SDL_FreeSurface(s.surface);
  SDL_DestroyTexture(s.texture);
  SDL_DestroyTexture(p.skin);
  for bTextureIndex:= 1 to High(b) do
    SDL_DestroyTexture(b[bTextureIndex].skin);
  for nTextureIndex:= 1 to High(n) do
    SDL_DestroyTexture(n[nTextureIndex].image);
  SDL_DestroyTexture(z.texture);

  SDL_DestroyRenderer(sdlRenderer);
  SDL_DestroyWindow(window);

  // closing SDL2
  SDL_Quit;

end.

