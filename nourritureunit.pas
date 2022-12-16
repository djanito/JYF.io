unit nourritureUnit;

// public  - - - - - - - - - - - - - - - - - - - - - - - - -
interface

uses SDL2, SDL2_image, sysutils, zoneUnit, playerUnit;

type
  Nourriture = record
      image: PSDL_Texture;
      rect: TSDL_Rect;
  end;

  TabNourriture = Array of Nourriture;

var
  tab: TabNourriture;

const
  NOURRITURE_SIZE = 24;

procedure GenerateNourriture(renderer: PSDL_Renderer; var tab: TabNourriture; diffPX, diffPY: Integer);

procedure TranslateNourriture(var tab: TabNourriture; pRect: TSDL_Rect);

procedure DisplayNourriture(renderer: PSDL_Renderer ; tabToDraw: TabNourriture);

procedure GenerateNourritureRect(var rect: TSDL_Rect; diffPX, diffPY: Integer);

function isNourritureCollide(n: TabNourriture; rectToCheck: TSDL_Rect; p: Player): Boolean;

// private  - - - - - - - - - - - - - - - - - - - - - - - - -
IMPLEMENTATION

procedure DisplayNourriture(renderer: PSDL_Renderer; tabToDraw: TabNourriture);
{ Boucle affichant à l'écran la totalité des nourritures }

var i : Integer;

begin
   for i := 1 to High(tabToDraw) do
       SDL_RenderCopy(renderer, tabToDraw[i].image , nil, @tabToDraw[i].rect);
end;

procedure GenerateNourritureRect(var rect: TSDL_Rect; diffPX, diffPY: Integer);
{ Génère une position aléatoire de la nourriture sur la zone de jeu }

begin
  rect.w := NOURRITURE_SIZE;
  rect.h := rect.w;
  rect.x := Random(ZONE_WIDTH - rect.w) - diffPX;
  rect.y := Random(ZONE_HEIGHT - rect.h) - diffPY;
end;

procedure GenerateNourriture(renderer: PSDL_Renderer; var tab: TabNourriture; diffPX, diffPY: Integer);
{ Génère un nombre fixé de nourritures avec comme attribut une texture choisi aléatoirement, une taille et une position }

const
    NbSkinNourriture: Integer = 7;
    NourritureNumber: Integer = 60;

var i: Integer;

begin
   setlength(tab, NourritureNumber+1);
   Randomize;

   for i := 1 to High(tab) do
     begin
       tab[i].image := IMG_LoadTexture(renderer, PChar('NOURRITURE/' + IntToStr(Random(NbSkinNourriture)+1) + '.png'));
       GenerateNourritureRect(tab[i].rect, diffPX, diffPY);
     end;
end;

procedure TranslateNourriture(var tab: TabNourriture; pRect: TSDL_Rect);
{ Déplace la nourriture dans la direction opposée à celle du joueur }

var i : Integer;

begin
   for i := 1 to High(tab) do
     begin
       tab[i].rect.x += round((WIN_WIDTH - pRect.w)/2) - pRect.x;
       tab[i].rect.y += round((WIN_HEIGHT - pRect.h)/2) - pRect.y;
     end;
end;

function isNourritureCollide(n: TabNourriture; rectToCheck: TSDL_Rect; p: Player): Boolean;
{ Permet de detecter si une entité à mangé de la nourriture grâce à un calcul de distance tout en regénérant la nourriture
mangée autre part }

var
  i: integer;
  diffX, diffY, distance, sizeDiff: Integer;
  isEatingPellet: Boolean = False;

begin
  for i := 1 to High(n) do
      begin
       diffX := rectToCheck.x - n[i].rect.x;
       diffY := rectToCheck.y - n[i].rect.y;
       sizeDiff := rectToCheck.w - NOURRITURE_SIZE;

       // PRE-VERIFICATION COLLIDE
       if (abs(diffX) <= sizeDiff) and (abs(diffY) <= sizeDiff) then
          begin
            distance := trunc(sqrt(sqr(diffX + sizeDiff/2) + sqr(diffY + sizeDiff/2)));
            if (distance <= trunc(sizeDiff/2)) then
               begin
                 isEatingPellet := True;

                 // RE-GENERATE NOURRIUTURE RECT ELSEWHERE
                 GenerateNourritureRect(n[i].rect, (p.relX - p.rect.x), (p.relY - p.rect.y));
                end;
           end
      end;
  isNourritureCollide := isEatingPellet;
end;

end.

