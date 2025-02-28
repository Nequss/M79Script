// Configures server settings for M79 climbing mode
//todo:
// Checkpoints
// top3 cp times

var
  // Player positions (index 1-32 represents player ID)
  PlayerX: Array[1..32] of Single;  // X coordinates
  PlayerY: Array[1..32] of Single;  // Y coordinates
  Timer: Array[1..32] of LongInt; // Timer for each player
  Alive: Array[1..32] of Boolean; // If players are alive
  DrawUI: Array[1..32] of Boolean; // Flags from drawing UI for specified player
  Speed: Array[1..32] of Extended; // Speed for each player

  GrenadeCount: Array[1..32] of Integer; // Count of grenades used
  FlamerShotCount: Array[1..32] of Integer; // Count of total flamer shots
  LastGrenadeAmount: Array[1..32] of Byte; // Last known grenade amount
  LastTotalAmmo: Array[1..32] of Byte; // Last known total ammo amount
  MapFinishes: Array[1..32] of Integer; // Count of map finishes
  Respawns: Array[1..32] of Integer; // Count of respawns
  Playtime: Array[1..32] of Integer; // Count of playtime

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

// Function to replace commas with dots in a string
function ReplaceCommasWithDots(const Input: string): string;
var
  i: Integer;
  Output: string;
begin
  Output := '';
  for i := 1 to Length(Input) do
  begin
    if Input[i] = ',' then
      Output := Output + '.'
    else
      Output := Output + Input[i];
  end;
  Result := Output;
end;


procedure SendHighscore(ID: byte; Map: string; Time: LongInt);
var highscore: string;
begin
  // Format: HS,127.0.0.1,John,M79_Map1,10000
  highscore := 'H$,' + IDToIP(ID) + ',' + IDToName(ID) + ',' + Map + ',' + IntToStr(Time);

  // Send highscore to the web page on docker via tcp
  WriteLn(highscore);
end;

procedure SendPlayerStats(ID: byte);
var 
  playerStats: string;
  TotalMilliseconds, Seconds : Integer;
begin
  // Format: PS,127.0.0.1,John,5,10,3600,2,8
  // P$,
  // IP, 
  // Name,
  // GrenadesThrown,
  // FlamerShots,
  // TimeSpentOnServer(in seconds),
  // MapFinishes, 
  // Respawns

  // 60 ticks = 1000 milliseconds (1 second)
  TotalMilliseconds := Playtime[ID] * (1000 div 60);

  // Calculate seconds
  Seconds := (TotalMilliseconds mod 60000) div 1000;

  playerStats := 'P$,' + 
                IDToIP(ID) + ',' + 
                ReplaceCommasWithDots(IDToName(ID)) + ',' + 
                IntToStr(GrenadeCount[ID]) + ',' + 
                IntToStr(FlamerShotCount[ID]) + ',' + 
                IntToStr(Seconds) + ',' +  // Convert ticks to seconds
                '1,' + //visited
                IntToStr(Respawns[ID]);
                
  // Send player stats to the web service via TCP
  WriteLn(playerStats);
end;

// Initialize stuff
procedure Ini;
var i: integer;
begin
  for i := 1 to 32 do
  begin
    // Initialize player prefs
    PlayerX[i] := 0;
    PlayerY[i] := 0;
    Timer[i] := 0;
    Alive[i] := false;
    DrawUI[i] := true;

    //stats
    GrenadeCount[i] := 0;
    FlamerShotCount[i] := 0;
    LastGrenadeAmount[i] := 0;
    LastTotalAmmo[i] := 0;
    MapFinishes[i] := 0;
    Respawns[i] := 0;
    Playtime[i] := 0;
  end;
end;


procedure OnJoinTeam(ID, Team: byte);
begin
  // Reset player prefs
  Alive[ID] := true;
  Timer[ID] := 0;
  PlayerX[ID] := 0;
  PlayerY[ID] := 0;

  // Reset grenade and flamer counters
  GrenadeCount[ID] := 0;
  FlamerShotCount[ID] := 0;
  LastGrenadeAmount[ID] := 0;
  LastTotalAmmo[ID] := 0;
  
  // Don't reset these on team join - they persist for the session
  // MapFinishes[ID] := 0;
  // Respawns[ID] := 0;

  //Anti-bravo 
  if Team = 2 then
  begin
    Command('/setteam1 ' + IntToStr(ID))
  end;
end;

procedure OnLeaveGame(ID, Team: Byte; Kicked: Boolean);
begin
  SendPlayerStats(ID);

  // Reset player prefs
  Alive[ID] := false;
  Timer[ID] := 0;
  PlayerX[ID] := 0;
  PlayerY[ID] := 0;

  // Reset all counters
  GrenadeCount[ID] := 0;
  FlamerShotCount[ID] := 0;
  LastGrenadeAmount[ID] := 0;
  LastTotalAmmo[ID] := 0;
  MapFinishes[ID] := 0;
  Respawns[ID] := 0;
  Playtime[ID] := 0;
end;

procedure OnPlayerRespawn(ID: Byte);
begin  
  Respawns[ID] := Respawns[ID] + 1;
  // If player has no saved location, set alive to true and reset timer
  if((PlayerX[ID] = 0) and (PlayerY[ID] = 0)) then
  begin
    Alive[ID] := true;
    Timer[ID] := 0;
  end
  else
  begin
    MovePlayer(ID, PlayerX[ID], PlayerY[ID]);
    SayToPlayer(ID, 'Loaded!');
  end;
end;

procedure OnPlayerKill(Killer, Victim: byte; Weapon: string);
begin
  // if player has no saved location, set alive to false and reset timer
  if((PlayerX[Victim] = 0) and (PlayerY[Victim] = 0)) then
  begin
    Alive[Victim] := false;
    Timer[Victim] := 0;
  end
end;

// Executes when a player joins the game
procedure OnJoinGame(ID: Byte; Team: Byte);
begin
  WriteConsole(ID, 'Welcome to the [Freestyle] M79 Climb ' + IDToName(ID) + '!', $EE81FAA1);
  WriteConsole(ID, 'Server is in development mode! Please stay tuned for leaderboard and more!', $EE81FAA1);
  WriteConsole(ID, 'Visit https://m79climb.nequs.space for more information!', $EE81FAA1);
  WriteConsole(ID, 'Type !ui to toggle UI! Use !help for available commands.', $EE81FAA1);
end;

procedure OnFlagScore(ID: Byte; TeamFlag: byte);
var Text: string;
begin
  // Increment map finishes counter
  MapFinishes[ID] := MapFinishes[ID] + 1;
  
  PlayerX[ID] := 0;
  PlayerY[ID] := 0;
  Alive[ID] := false;

  Text := IDToName(ID) + ' finished the map in ' + ReturnTimer(Timer[ID]);

  WriteConsole(0, Text, $EE81FAA1);
  WriteLn(Text);

  SendHighscore(ID, CurrentMap, Timer[ID]);
  SendPlayerStats(ID); // Also send player stats when they finish a map
  DoDamage(ID, 4000);

  Timer[ID] := 0; // at the end reset timer
end;

procedure OnMapChange(NewMap: string);
var  
  i: integer;
begin
  for i := 1 to 32 do
  begin
    // Reset player prefs
    PlayerX[i] := 0;
    PlayerY[i] := 0;
    Timer[i] := 0;
  end;
end;

procedure DisplayTop(Map: string);
var
  response: string; 
begin
  // https doesn't work
  response := GetUrl('http://m79climb.nequs.space/api/besttimes/' + CurrentMap + '/5');
  WriteConsole(0, response, $EA11F3A1);
end;

procedure DisplayMyTop(ID: byte; Map: string);
var  //
  response: string;
begin
  // https doesn't work
  response := GetUrl('http://m79climb.nequs.space/api/times/' + IDToIP(ID) + '/' + IDToName(ID) + '/' + CurrentMap + '/5');
  WriteConsole(0, response, $EA11F3A1);
end;


// Executes when a player speaks
procedure OnPlayerSpeak(ID: Byte; Text: string);
begin
  case lowercase(getpiece(Text, ' ', 0)) of 
    '!v': 
      Command('/nextmap');

    '!save': 
      begin
        PlayerX[ID] := GetPlayerStat(ID, 'X');
        PlayerY[ID] := GetPlayerStat(ID, 'Y');
        SayToPlayer(ID, 'Location has been saved!');
      end;
    
    '!load': 
      begin
        if((PlayerX[ID] = 0) and (PlayerY[ID] = 0)) then
          SayToPlayer(ID, 'No saved location found!')
        else begin
          MovePlayer(ID, PlayerX[ID], PlayerY[ID]);
          SayToPlayer(ID, 'Loaded!');
        end;
      end;
    
    '!remove': 
      begin
        PlayerX[ID] := 0;
        PlayerY[ID] := 0;
        SayToPlayer(ID, 'Save/Load point has been removed!');
      end;
    
    '!top':
      begin
        DisplayTop(CurrentMap);
      end;
    
    '!mytop':
      begin
        DisplayMyTop(ID, CurrentMap);
      end;
    
    '!help':
      begin
        WriteConsole(0, 'Available commands: !ui, !save, !load, !remove, !v, !top, !mytop', $EE81FAA1);
      end;

     '!ping':
      begin
        WriteConsole(0, 'Ping: ' + IntToStr(GetPlayerStat(ID, 'Ping')), $EE81FAA1);
      end;

    '!ui':
      begin
        if DrawUI[ID] = true then
        begin
          DrawUI[ID] := false;
          WriteConsole(ID, 'UI disabled!', $EE81FAA1);
        end
        else
        begin
          DrawUI[ID] := true;
          WriteConsole(ID, 'UI enabled!', $EE81FAA1);
        end;
      end;
  end;
end;

// Track weapon and granades usage and count total flamer shots + nades
procedure TrackWeaponUsage(ID: Byte);
var
  CurrentGrenades, CurrentPrimaryAmmo, CurrentSecondaryAmmo, CurrentTotalAmmo: Byte;
begin
  if not Alive[ID] then Exit;
  
  // Get current amounts
  CurrentGrenades := GetPlayerStat(ID, 'Grenades');
  CurrentPrimaryAmmo := GetPlayerStat(ID, 'Ammo');
  CurrentSecondaryAmmo := GetPlayerStat(ID, 'SecAmmo');
  
  // Calculate total ammo (max 2)
  CurrentTotalAmmo := CurrentPrimaryAmmo + CurrentSecondaryAmmo;
  if CurrentTotalAmmo > 2 then CurrentTotalAmmo := 2;
  
  // Check if total ammo decreased (a shot was fired)
  if (LastTotalAmmo[ID] > CurrentTotalAmmo) and (LastTotalAmmo[ID] > 0) then
  begin
    // Count the difference as shots fired
    FlamerShotCount[ID] := FlamerShotCount[ID] + (LastTotalAmmo[ID] - CurrentTotalAmmo);
  end;
  
  // Update total ammo
  LastTotalAmmo[ID] := CurrentTotalAmmo;
  
  // Check for grenade usage
  if (LastGrenadeAmount[ID] > CurrentGrenades) and (LastGrenadeAmount[ID] > 0) then
  begin
    // Count the difference as grenades used
    GrenadeCount[ID] := GrenadeCount[ID] + (LastGrenadeAmount[ID] - CurrentGrenades);
  end;
  
  // Update grenade count
  LastGrenadeAmount[ID] := CurrentGrenades;
end;

// Main loop
procedure AppOnIdle(Ticks: Integer);
var 
  S: integer;
  xSpeed: Extended;
  ySpeed: Extended;

begin
  AppOnIdleTimer := 1; // Default = 60 = 1 second 

  // Check every aprx. 2 minutes
  if Ticks mod (3600 * 2) = 0 then
  begin
    WriteConsole(0, '!help for available commands!', $EE81FAA1);
    WriteConsole(0, 'Current Map: ' + CurrentMap + ' Next Map: ' + NextMap, $EE81FAA1);
  end;

  for S := 1 to 32 do
  begin
    // Track weapon usage every tick
    TrackWeaponUsage(S);

    // Increment playtime every tick
    Playtime[S] := Playtime[S] + 1;

    // Check if player is alive and if so calculate and draw timer
    if Alive[S] = true then
    begin
      Timer[S] := Timer[S] + 1;

      // Calculating speed vector
      // This works because the speed is the length of the vector representing movement in both X and Y directions.
      xSpeed := GetPlayerStat(S, 'VelX');
      ySpeed := GetPlayerStat(S, 'VelY');
      Speed[S] :=  100 * sqrt((xSpeed*xSpeed) + (ySpeed*ySpeed)); // Multiplied by 100 to make it more readable by players
      //Speed[S] := Round(Speed[S]);

      if DrawUI[S] = true then
      begin
          DrawTextEx(S, 2, 'Time: ' + ReturnTimer(Timer[S]), 100, RGB(255,255,255), 0.07, 1, 100);
          DrawTextEx(S, 3, 'Velocity: ' + IntToStr(Round(Speed[S])), 100, RGB(255,255,255), 0.07, 1, 115);
      end;
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

// Initialize the game mode settings
begin
  Ini;
end.