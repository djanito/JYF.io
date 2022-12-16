unit IAunit;

interface

uses SDL2, SDL2_image, nourritureUnit, playerUnit, zoneUnit, SysUtils, Math;

type
  IA = record
    skin: PSDL_Texture;
    name: String;
    rect: TSDL_Rect;
    score: Integer;
    relX, relY: Integer;
    direction: TSDL_Point;
    isDefending: Boolean;
    isRotating: Boolean;
  end;

  TabIA = Array of IA;
  ColidePoints = array [0..1] of Vector;

const
  NUMBER_IA = 1;
  INITIAL_IA_SIZE = 63;
  NUMBER_SKINS = 12;

procedure GenerateIA(renderer: PSDL_Renderer; var b: TabIA; diffPX, diffPY: Integer);
procedure TranslateIA(var b: TabIA; p: Player);
procedure UpdateIA(var bot: IA; newSize: Real);
procedure TakeIADecision(b: TabIA; p: Player; n: TabNourriture; renderer: PSDL_Renderer);
procedure RegenerateIAOnDeath(var bot: IA; diffPX, diffPY: Integer);

implementation

procedure ShuffleList(var names: Array of String);
{ Trie aléatoirement les données d'une liste de noms }

var i, randomIndex: integer;
  name: String;

begin
  Randomize();
  for i := 1 to high(names) do
    begin
      randomIndex := random(high(names))+1;
      name := names[i];
      names[i] := names[randomIndex];
      names[randomIndex] := name;
    end;
end;

function GenerateIARect(diffPX, diffPY: Integer): TSDL_Rect;
{ Génère une position aléatoire de l'IA sur la zone de jeu }

var rect: TSDL_Rect;

begin
  rect.w := INITIAL_IA_SIZE - Random(15);
  rect.h := rect.w;
  rect.x := Random(ZONE_WIDTH - rect.w) - diffPX;
  rect.y := Random(ZONE_HEIGHT - rect.h) - diffPY;

  GenerateIARect := rect;
end;

procedure RegenerateIAOnDeath(var bot: IA; diffPX, diffPY: Integer);
{ Réinitialise certains attributs de l'IA à sa mort }

begin
  bot.rect := GenerateIARect(diffPX, diffPY);
  bot.score := round(sqr(bot.rect.w)/400);
  bot.isDefending := False;
  bot.isRotating := False;
end;

procedure GenerateIA(renderer: PSDL_Renderer; var b: TabIA; diffPX, diffPY: Integer);
{ Génère un nombre fixé de nourritures avec comme attributs:
  - une texture choisi aléatoirement
  - un nom choisialéatoire
  - une taille
  - une position }

var i: Integer;
    Names: Array [1..19] of String = ('Djan', 'Mattéo', 'Louis', 'Damien', 'Pierre', 'Amin', 'Mathias', 'Alexandre', 'Léandre', 'Vacances', 'Dudu', '2020', 'M3', 'P5', 'M6', 'P4', 'P1 :(', 'C3', 'T1');

begin
   setlength(b, Min(NUMBER_IA, 20) + 1);
   ShuffleList(Names);
   for i := 1 to High(b) do
     begin
       b[i].skin := IMG_LoadTexture(renderer, PChar('SKINS/' + IntToStr(Random(NUMBER_SKINS)+1) + '.png'));
       if b[i].skin = nil then HALT;

       if (i = 1) then
          b[i].name := 'Mr. Bourgais'
       else
         b[i].name := Names[i];

       b[i].rect := GenerateIARect(diffPX, diffPY);
       b[i].relX := diffPX + b[i].rect.x;
       b[i].relY := diffPY + b[i].rect.y;
       b[i].score := round(sqr(b[i].rect.w)/400);
       b[i].direction.x := round(b[i].rect.x + b[i].rect.w/2);
       b[i].direction.y := round(b[i].rect.y + b[i].rect.h/2);
       b[i].isDefending := False;
       b[i].isRotating := False;
     end;
end;

procedure UpdateIA(var bot: IA; newSize: Real);
{ Modifie certains attributs de l'IA lors d'un évènement }

begin
   bot.rect.w := round(newSize);
   bot.rect.h := bot.rect.w;
   bot.score := round(sqr(bot.rect.w)/400);
end;

procedure TranslateIA(var b: TabIA; p: Player);
{ Déplace les IA dans la direction opposée à celle du joueur }

var i: Integer;

begin
   for i := 1 to High(b) do
     begin
       b[i].relX := (p.relX - p.rect.x) + b[i].rect.x;
       b[i].relY := (p.relY - p.rect.y) + b[i].rect.y;
       b[i].rect.x += round((WIN_WIDTH - p.rect.w)/2) - p.rect.x;
       b[i].rect.y += round((WIN_HEIGHT - p.rect.h)/2) - p.rect.y;
       b[i].direction.x += round((WIN_WIDTH - p.rect.w)/2) - p.rect.x;
       b[i].direction.y += round((WIN_HEIGHT - p.rect.h)/2) - p.rect.y;
     end;
end;

procedure DeplaceIA(var bot: IA; p: Player; point: TSDL_Point);
{ Deplace l'IA au point passé en argument
  On multiplie à la fin par la formule d'Agario de la vitesse de dépacement en fonction du score
  Enfin on regarde si le déplacement peut s'effectuer sans sortir de la zone de jeu
}

var
  vect: Vector;
  dx, dy, s: real;

begin
   // CALCULATE VECTOR
   vect[0] := point.x - (bot.rect.x + bot.rect.w/2);
   vect[1] := point.y - (bot.rect.y + bot.rect.h/2);

   if (sqr(vect[0]) + sqr(vect[1]) <> 0) then
      begin
        dx := vect[0]/sqrt(sqr(vect[0]) + sqr(vect[1]));
        dy := vect[1]/sqrt(sqr(vect[0]) + sqr(vect[1]));

        s := getSpeed(bot.score);

        bot.relX := (p.relX - p.rect.x) + bot.rect.x;
        bot.relY := (p.relY - p.rect.y) + bot.rect.y;

        CheckCollisionBorder(bot.rect, bot.relX, bot.relY, dx * s, dy * s);
      end;
end;

function ResizeVector(bXCenter, bYCenter: Real; vect: TSDL_Point; size: Real): TSDL_Point;
{ Permet de redimensionner un vecteur selon la taille choisie }

var norme: Real;

begin
   vect.x := round(vect.x - bXCenter);
   vect.y := round(vect.y - bYCenter);

   norme := sqrt(sqr(vect.x) + sqr(vect.y));
   if (norme <> 0) then
      begin
        vect.x := round(bXCenter + round((size/norme) * vect.x));
        vect.y := round(bYCenter + round((size/norme) * vect.y));
      end;

   ResizeVector := vect;
end;


// ------------- IA PART -------------
function PlusProcheNourriture(bot: IA; n: TabNourriture): TSDL_Point;
{ Algorithme des K-nearest neighbors permettant de récupérer la position de la nourriture la plus proche d'une IA}

var
  nPlusProche: TSDL_Point;
  d1, d2: Real;
  i: Integer;

begin

  nPlusProche.x := round(n[1].rect.x + n[1].rect.w/2);
  nPlusProche.y := round(n[1].rect.y + n[1].rect.h/2);
  for i:= 2 to High(n) do
      begin
        d1 := sqr((bot.rect.x + bot.rect.w/2) - (n[i].rect.x + NOURRITURE_SIZE/2)) + sqr((bot.rect.y + bot.rect.h/2) - (n[i].rect.y + NOURRITURE_SIZE/2));
        d2 := sqr((bot.rect.x + bot.rect.w/2) - (nPlusProche.x + NOURRITURE_SIZE/2)) + sqr((bot.rect.y + bot.rect.h/2) - (nPlusProche.y + NOURRITURE_SIZE/2));
        if (d1 < d2) then
           begin
             nPlusProche.x := round(n[i].rect.x + n[i].rect.w/2);
             nPlusProche.y := round(n[i].rect.y + n[i].rect.h/2);
           end;
      end;

  PlusProcheNourriture := nPlusProche;
end;

procedure GetCircleCollidePoints(i: Integer; var b: TabIA; p: Player; var defendPoints: TabCollidePoints; var attackPoints: SetofPoints);
{ Récupère dans un tableau tout les points de collisions (si ils existent) entre chaque IA et le reste des IA ainsi qu'avec le joueur:
  - Si l'IA est 11% plus grosse que l'ennemie: on ajoute la position de l'ennemie à la liste attackPoints
  - Si l'IA est 11% plus petite que l'ennemie: on calcul les points d'intersections cercle-cercle.
}

var
  j, startIndex: Integer;
  rect: TSDL_Rect;
  dCircles, commonPart: Real;
  p1, p2: TSDL_Point;

begin
  setLength(defendPoints, 0);
  setLength(attackPoints, 0);
  if (p.isAlive) then
     startIndex := 0
  else
    startIndex := 1;
  for j := startIndex to High(b) do
     begin
       if (j <> i) then
          begin

          if (j = 0) then
             rect := p.rect
          else
            rect := b[j].rect;

            p1.x := round(rect.x + rect.w/2);
            p1.y := round(rect.y + rect.h/2);
            p2.x := round(b[i].rect.x + b[i].rect.w/2);
            p2.y := round(b[i].rect.y + b[i].rect.h/2);

            // CHECK IF IA TOUCH DANGER ZONE
            dCircles := sqrt(sqr(p1.x - p2.x) + sqr(p1.y - p2.y));
            if (dCircles <> 0) and (sqr(DETECTION_CIRCLE_RADIUS/dCircles) >= 1) and (dCircles < DETECTION_CIRCLE_RADIUS + rect.w/2) then
               begin
                  if (0.89 * rect.w > b[i].rect.w) then
                    begin
                      // ------ DEFEND PART ------
                      setlength(defendPoints, length(defendPoints)+1);

                      // get 2 points of intersection (circle-circle intersection formula)GET TWO POINT OF INTERSECTION (CIRCLE-CIRCLE POINTS INTERSECTION FORMULA)
                      commonPart := sqrt(sqr(DETECTION_CIRCLE_RADIUS/dCircles) - 1);

                      defendPoints[High(defendPoints)][0].x := round(1/2 * (p1.x + p2.x) - commonPart * (p2.y - p1.y));
                      defendPoints[High(defendPoints)][0].y := round(1/2 * (p1.y + p2.y) - commonPart * (p1.x - p2.x));

                      defendPoints[High(defendPoints)][1].x := round(1/2 * (p1.x + p2.x) + commonPart * (p2.y - p1.y));
                      defendPoints[High(defendPoints)][1].y := round(1/2 * (p1.y + p2.y) + commonPart * (p1.x - p2.x));
                    end
                  else if (0.89 * b[i].rect.w > rect.w) and (dCircles < 3/4 * DETECTION_CIRCLE_RADIUS) then
                    begin
                       // ------ ATTACK PART ------
                       setlength(attackPoints, length(attackPoints)+1);
                       attackPoints[High(attackPoints)] := p1;
                    end;
               end;
           end;
     end;
end;

procedure GetCenterVector(bot: IA; var centerPoint: TSDL_Point; collidePoints: TabCollidePoints; renderer: PSDL_Renderer);
{ 1) Calcul chaque vecteur central entre les deux vecteurs reliant les 2 points d'intersections
  2) Fais la somme des vecteurs individuels afin d'obtenir un vecteur direction final.
}

var
  collideIndex, bXCenter, bYCenter: Integer;
  collideVect1, collideVect2, collideVectTot, midVect: TSDL_Point;

begin
  bXCenter := round(bot.rect.x + bot.rect.w/2);
  byCenter := round(bot.rect.y + bot.rect.h/2);

  midVect.x := 0;
  midVect.y := 0;

  SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);

  for collideIndex := 0 to High(collidePoints) do
    begin
      // DRAW INTERSECTION LINES
      SDL_RenderDrawLine(renderer, collidePoints[collideIndex][0].x, collidePoints[collideIndex][0].y, bXCenter, bYCenter);
      SDL_RenderDrawLine(renderer, collidePoints[collideIndex][1].x, collidePoints[collideIndex][1].y, bXCenter, bYCenter);

      // CALCULATE EACH MIDDLE VECTOR
      collideVect1.x := bXCenter - collidePoints[collideIndex][0].x;
      collideVect1.y := bYCenter - collidePoints[collideIndex][0].y;
      collideVect2.x := bXCenter - collidePoints[collideIndex][1].x;
      collideVect2.y := bYCenter - collidePoints[collideIndex][1].y;

      collideVectTot.x := collideVect1.x + collideVect2.x;
      collideVectTot.y := collideVect1.y + collideVect2.y;

      // ADD EACH SINGLE MID VECT
      midVect.x += collideVectTot.x;
      midVect.y += collideVectTot.y;
    end;

  midVect.x += bXCenter;
  midVect.y += bYCenter;

  // RESIZE THE FINAL VECT NORM
  midVect := ResizeVector(bXCenter, bYCenter, midVect, DETECTION_CIRCLE_RADIUS);

  centerPoint := midVect;
end;

function isVectorOutside(bot: IA): Boolean;

{ Retourne True si le point de direction sort de la zone de jeu
  Retourne False sinon
}

var
  relDirX, relDirY: Integer;

begin
  relDirX := bot.relX - (bot.rect.x - bot.direction.x);
  relDirY := bot.relY - (bot.rect.y - bot.direction.y);

  // if direction point outside
  if (relDirX < 0) or (relDirX > ZONE_WIDTH) or (relDirY < 0) or (relDirY > ZONE_HEIGHT) then
     isVectorOutside := True
  else if (relDirX >= 0) and (relDirX <= ZONE_WIDTH) and (relDirY >= 0) and (relDirY <= ZONE_HEIGHT) then
     isVectorOutside := False;

end;

procedure TakeIADecision(b: TabIA; p: Player; n: TabNourriture; renderer: PSDL_Renderer);
{ Gère le comportement global de tout les IA par des conditions:
  - détermine quand attaquer
  - détermine quand défendre
  - choisir quand l'IA doit aller la nourriture la plus proche etc..
}

var
  botIndex: Integer;
  bXCenter, bYCenter, r, theta: Real;
  defendPoints: TabCollidePoints;
  attackPoints : SetofPoints;
  centerPoint: TSDL_Point;

begin
  // FOR EACH IA
  for botIndex:= 1 to High(b) do
    begin
      bXCenter := b[botIndex].rect.x + b[botIndex].rect.w/2;
      bYCenter := b[botIndex].rect.y + b[botIndex].rect.h/2;

      // GO TO THE NEAREST FOOD IS THE IA IS NOT ATTACKED OR IN A WALL
      if (b[botIndex].isRotating = False) and (b[botIndex].isDefending = False) then
         b[botIndex].direction := PlusProcheNourriture(b[botIndex], n);

      if (isVectorOutside(b[botIndex]) = False) then
         GetCircleCollidePoints(botIndex, b, p, defendPoints, attackPoints);

      if (length(defendPoints) > 0) and (length(defendPoints) >= length(attackPoints)) then
        begin
          // DEFEND BEHAVIOR
          b[botIndex].isDefending := True;
          if (isVectorOutside(b[botIndex]) = False) and (b[botIndex].isRotating = False) then
            begin
              // get the final direction vect.
              GetCenterVector(b[botIndex], centerPoint, defendPoints, renderer);
              b[botIndex].direction := centerPoint;
            end;
        end
      else if (length(attackPoints) > 0) and (b[botIndex].isDefending = False) then
        // ATTACK BEHAVIOR
         b[botIndex].direction := attackPoints[0];


      // REINITIALIZE IA ATTRIBUTES IF IT IS ON THE POSITION POINT
      if (trunc(sqrt(sqr(b[botIndex].direction.x - bXCenter) + sqr(b[botIndex].direction.y - bYCenter))) < 5) then // < 5 cuz speed is too high and miss pixels
        begin
          b[botIndex].isRotating := False;
          b[botIndex].isDefending := False;
        end;

      // IF VECTOR OUTSIDE THE AREA OR IA IN A WALL AND VECT IN THE CIRCLE OF THE IA
      if isVectorOutside(b[botIndex]) or (((b[botIndex].relX = 0) or
          (b[botIndex].relY = 0) or
          (b[botIndex].relX + b[botIndex].rect.w = ZONE_WIDTH) or
          (b[botIndex].relY + b[botIndex].rect.h = ZONE_HEIGHT)) and
          (b[botIndex].direction.x >= b[botIndex].rect.x) and
          (b[botIndex].direction.x <= b[botIndex].rect.x + b[botIndex].rect.w) and
          (b[botIndex].direction.y >= b[botIndex].rect.y) and
          (b[botIndex].direction.y <= b[botIndex].rect.y + b[botIndex].rect.h)) then
          begin
            // ROTATE THE DIRECTION VECT TO A RANDOM LOCATION BUT WITH THE SAME NORM
            b[botIndex].isRotating := True;
            r := sqrt(sqr(b[botIndex].direction.x - bXCenter) + sqr(b[botIndex].direction.y - bYCenter)) * sqrt(Random(100)/100);
            theta := Random(100)/100 * 2 * Pi;
            b[botIndex].direction.x := round(bXCenter + r * cos(theta));
            b[botIndex].direction.y := round(bYCenter + r * sin(theta));
            b[botIndex].direction := ResizeVector(bXCenter, bYCenter, b[botIndex].direction, DETECTION_CIRCLE_RADIUS);
          end;

       // DRAW FINAL DEFEND VECTOR
       SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255);
       SDL_RenderDrawLine(renderer, b[botIndex].direction.x, b[botIndex].direction.y, round(bXCenter), round(bYCenter));

       DeplaceIA(b[botIndex], p, b[botIndex].direction);
      end;
end;

end.

