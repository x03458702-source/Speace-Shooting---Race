using System.Collections.Generic;
using Godot;
using SpaceShootingRace.Races;

namespace SpaceShootingRace;

public partial class GameSetup : Node3D
{
    [Export] public int TotalLaps { get; set; } = 2;
    [Export] public double CountdownSeconds { get; set; } = 3.0;

    public override void _Ready()
    {
        var manager = GetNodeOrNull<RaceManager>("/root/RaceManager");
        if (manager == null) return;

        var players = new List<RaceParticipant> { GetNode<RaceParticipant>("Player/RaceParticipant") };

        // Suscripción a las señales del RaceManager utilizando métodos o expresiones lambda
        manager.LapCompleted += OnLapCompleted;
        manager.RaceStarted += OnRaceStarted;
        manager.RaceFinished += OnRaceFinished;

        // Iniciar la carrera pasando la lista de jugadores, vueltas y el tiempo de cuenta atrás
        manager.StartRace(players, TotalLaps, CountdownSeconds);
    }

    private void OnLapCompleted(RaceParticipant participant, int lap, int totalLaps)
    {
        GD.Print($"¡Vuelta {lap} de {totalLaps} completada!");
    }

    private void OnRaceStarted(RaceManager manager, double timestamp)
    {
        GD.Print("¡Cuenta atrás finalizada, la carrera ha comenzado!");
    }

    private void OnRaceFinished(RaceParticipant participant, double time, int position)
    {
        GD.Print($"Participante ha terminado la carrera en la posición {position} con un tiempo de {time:F2} segundos.");
    }
}