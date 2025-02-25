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
    DrawUI[i] := true;
  end;
end;

procedure OnJoinTeam(ID, Team: byte);
begin
  Alive[ID] := true;
  Timer[ID] := 0;
  PlayerX[ID] := 0;
  PlayerY[ID] := 0;
end;

procedure OnLeaveGame(ID, Team: Byte; Kicked: Boolean);
begin
  Alive[ID] := false;
  Timer[ID] := 0;
  PlayerX[ID] := 0;
  PlayerY[ID] := 0;
end;

procedure OnPlayerRespawn(ID: Byte);
begin
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
  WriteConsole(0, 'Welcome to the [Freestyle] M79 Climb ' + IDToName(ID) + '! Use !help for available commands.', $EE81FAA1);
  WriteConsole(0, 'Server is in development mode! Please stay tuned for leaderboard and more!', $EE81FAA1);
  WriteConsole(0, 'Visit https://m79climb.nequs.space for more information!', $EE81FAA1);

  //if(IDToName(ID) = 'Mayor') then
  //  WriteConsole(ID, 'Mayor is not allowed to play! Change your nickname!', $EE81FAA1);
end;

procedure SendHighscore(ID: byte; Map: string; Time: LongInt);
var highscore: string;
begin
  // Format: HS,127.0.0.1,John,M79_Map1,10000
  highscore := 'H$,' + IDToIP(ID) + ',' + IDToName(ID) + ',' + Map + ',' + IntToStr(Time);

  // Send highscore to the web page on docker via tcp
  WriteLn(highscore);
end;

procedure OnFlagScore(ID: Byte; TeamFlag: byte);
var Text: string;
begin
  PlayerX[i] := 0;
  PlayerY[i] := 0;
  Timer[i] := 0;
  Alive[i] := false;

  Text := IDToName(ID) + ' finished the map in ' + ReturnTimer(Timer[ID]);

  WriteConsole(0, Text, $EE81FAA1);
  WriteLn(Text);

  SendHighscore(ID, CurrentMap, Timer[ID]);
  DoDamage(ID, 4000);
end;

procedure DisplayTop(Map: string);
var
  response: string; 
begin
  // https doesn't work
  response := GetUrl('http://m79climb.nequs.space/api/besttimes/' + CurrentMap + '/10');
  WriteConsole(0, response, $EA11F3A1);
end;

procedure DisplayMyTop(ID: byte; Map: string);
var 
  response: string;
begin
  // https doesn't work
  response := GetUrl('http://m79climb.nequs.space/api/times/' + IDToIP(ID) + '/' + IDToName(ID) + '/' + CurrentMap);
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
        WriteConsole(0, 'Available commands: !save, !load, !remove, !v, !top, !mytop', $EE81FAA1);
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

// Main loop
procedure AppOnIdle(Ticks: Integer);
var 
  S: integer;
  xSpeed: Extended;
  ySpeed: Extended;
begin
  AppOnIdleTimer := 1; // Default = 60 = 1 second 

  if Ticks mod 6 = 0 then  // Check every 100ms (1/10th of a second)
  begin
    // Your code here
  end;

  // Check every aprx. 5 minutes
  if Ticks mod (3600 * 5) = 0 then
  begin
    WriteConsole(0, '!help for available commands!', $EE81FAA1);
    WriteConsole(0, 'Current Map: ' + CurrentMap + ' Next Map: ' + NextMap, $EE81FAA1);
  end;

  // Check every 1 s
  if Ticks mod 60 = 0 then
  begin
    // More code here
  end;

  for S := 1 to 32 do
  begin
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
