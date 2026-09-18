using System.Collections.Generic;
using Godot;
using SpaceShootingRace.Racing;

namespace SpaceShootingRace;

public partial class GameSetup : Node3D
{
    [Export] public int TotalLaps { get; set; } = 2;
    [Export] public double CountdownSeconds { get; set; } = 3.0;

    public override void _Ready()
    {
        var manager = GetNodeOrNull<RaceManager>("/root/RaceManager");
        if (manager == null) return;

        var participant = GetNode<RaceParticipant>("Player/RaceParticipant");
        participant.Connect(
            RaceParticipant.SignalName.LapCompleted,
            Callable.From<RaceParticipant, int, int>(OnLapCompleted));
        participant.Connect(
            RaceParticipant.SignalName.RaceFinished,
            Callable.From<RaceParticipant, double, int>(OnRaceFinished));
        participant.Connect(
            RaceParticipant.SignalName.Eliminated,
            Callable.From<RaceParticipant>(OnEliminated));

        var players = new List<RaceParticipant> { participant };
        manager.StartRace(players, TotalLaps, CountdownSeconds);
    }

    private void OnLapCompleted(RaceParticipant participant, int lap, int totalLaps)
    {
        GD.Print($"[Jugador] Vuelta {lap}/{totalLaps} completada. Posición: {participant.CurrentPosition}");
    }

    private void OnRaceFinished(RaceParticipant participant, double time, int position)
    {
        GD.Print($"[Jugador] Carrera finalizada en posición {position} con tiempo {time:F2}s");
    }

    private void OnEliminated(RaceParticipant participant)
    {
        GD.Print("[Jugador] ¡Todas las vidas perdidas!");
    }
}