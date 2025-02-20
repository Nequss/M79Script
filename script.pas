// Configures server settings for M79 climbing mode
//todo:
// Checkpoints
// ranking top10
// top3 cp times

var
  // Player positions (index 1-32 represents player ID)
  PlayerX: array[1..32] of Single;  // X coordinates
  PlayerY: array[1..32] of Single;  // Y coordinates
  Timer: Array[1..32] of LongInt; // Timer for each player
  Alive: array[1..32] of Boolean; // If players are alive

// Returns the timer in the format "Minutes:Seconds:Miliseconds" Value = Ticks
function ReturnTimer(Ticks: LongInt): String;
var
  TotalMilliseconds, Minutes, Seconds, Milliseconds: Integer;
begin
  // 60 ticks = 1000 milliseconds (1 second)
  TotalMilliseconds := Ticks * (1000 div 60);

  // Calculate minutes, seconds, and milliseconds
  Minutes := TotalMilliseconds div 60000;
  Seconds := (TotalMilliseconds mod 60000) div 1000;
  Milliseconds := TotalMilliseconds mod 1000;

  Result := IntToStr(Minutes) + ':' + IntToStr(Seconds) + ':' + IntToStr(Milliseconds);
end;

// Initialize the timer for Players
procedure Ini;
var i: integer;
begin
  for i := 1 to 32 do
  begin
    PlayerX[i] := 0;
    PlayerY[i] := 0;
    Timer[i] := 0;
    Alive[i] := false;
  end;
end;

procedure OnPlayerRespawn(ID: Byte);
begin
  if((PlayerX[ID] = 0) and (PlayerY[ID] = 0)) then
  begin
    Alive[ID] := true;
    Timer[ID] := 0;
  end
  else
    MovePlayer(ID, PlayerX[ID], PlayerY[ID]);
end;

procedure OnJoinTeam(ID, Team: byte);
begin
  Alive[ID] := true;
end;  

procedure OnPlayerKill(Killer, Victim: byte; Weapon: string);
begin
  if((PlayerX[Victim] = 0) and (PlayerY[Victim] = 0)) then
  begin
    Alive[Victim] := false;
    Timer[Victim] := 0;
  end
end;

// Main loop
procedure AppOnIdle(Ticks: Integer);
var S: integer;
begin
  AppOnIdleTimer := 1; // Default = 60 = 1 second

  // Check every 5 minutes
  if Ticks mod (3600 * 5) = 0 then
  begin
    WriteConsole(0, '!help for available commands!', $EE81FAA1);
    WriteConsole(0, 'Current Map: ' + CurrentMap + ' Next Map: ' + NextMap, $EE81FAA1);
  end;

  // Check every 1 s
  if Ticks mod 60 = 0 then
  begin
    // WriteConsole(0, '1 second passed', $EE81FAA1);
    // More code here
  end;

  for S := 1 to 32 do
  begin
    // Check if player is alive and if so calculate and draw timer
    if Alive[S] = true then
    begin
      Timer[S] := Timer[S] + 1;
      DrawText(S, 'Timer: ' + ReturnTimer(Timer[S]), 100, RGB(255,255,255), 0.10, 1, 100);
    end;

    // Check if player has no primary weapon
    if GetPlayerStat(S, 'Primary') = 255 then
    begin
      ForceWeaponEx(S, 11, 11, 1, 1); // Give primary weapon Flamer
    end;

    if GetKeyPress(S, 'Reload') = true then DoDamage(S, 4000); // Damage player on R key press
    if GetPlayerStat(S, 'Grenades') < 2 then GiveBonus(S, 4); // Give grenades
  end;
end;

// Executes when a player joins the game
procedure OnJoinGame(ID: Byte; Team: Byte);
begin
  WriteConsole(0, 'Welcome to the [Freestyle] M79 Climb ' + IDToName(ID) + '! Use !help for available commands.', $EE81FAA1);
end;

// Saves the highscore to the highscore.json file, 
// then the file is sent to the web page by vps server script 
procedure SendHighscore(ID: byte; Map: string; Time: LongInt);
var json: string;
begin
  json := '{"Ip": "' + IDToIP(ID) + '", "Name": "' + IDToName(ID) + '", "Map": "' + Map + '", "Time": ' + IntToStr(Time) + '}';
  WriteFile('highscore.json', json);
end;

procedure OnFlagScore(ID: Byte; TeamFlag: byte);
begin
  WriteConsole(0, IDToName(ID) + ' finished the map in ' + ReturnTimer(Timer[ID]), $EE81FAA1);
  SendHighscore(ID, CurrentMap, Timer[ID]);
  DoDamage(ID, 4000);
end;


procedure DisplayTop(Map: string);
begin
  // to do
end;

procedure DisplayMyTop(ID: byte; Map: string);
begin

end;

// Executes when a player speaks
procedure OnPlayerSpeak(ID: Byte; Text: string);
begin
  case lowercase(getpiece(Text, ' ', 0)) of 
    // '!quit': Shutdown;
    '!next', '!nextmap', '!nm', '!v': Command('/nextmap');
    '!top': begin
              DisplayTop(CurrentMap);
            end;
    '!mytop': begin
                DisplayMyTop(ID, CurrentMap);
              end;
    '!save': begin
                PlayerX[ID] := GetPlayerStat(ID, 'X');
                PlayerY[ID] := GetPlayerStat(ID, 'Y');
                SayToPlayer(ID, 'Location has been saved!');
             end;
    '!load': begin
                MovePlayer(ID, PlayerX[ID], PlayerY[ID]);
                SayToPlayer(ID, 'Loaded!');
             end;  
    '!remove': begin
                PlayerX[ID] := 0;
                PlayerY[ID] := 0;
                SayToPlayer(ID, 'Save/Load point has been removed!');
                end;
    '!help': begin
               WriteConsole(0, 'Available commands: !save, !load, !remove, !next, !nextmap, !nm', $EE81FAA1);
             end; 
    '!top', '!top10', '!best', '!times': begin
                                            DisplayTop(CurrentMap);
                                         end; 
    '!mytop', '!mybest', '!mytimes': begin
                                       DisplayMyTop(ID, CurrentMap);
                                     end;
  end;
end;

// Initialize the game mode settings
begin
  Ini;
end.