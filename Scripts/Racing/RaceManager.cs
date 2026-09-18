using Godot;
using System.Collections.Generic;
using System.Linq;

namespace SpaceShootingRace.Races;

public enum RaceState
{
    Idle,
    Countdown,
    Racing,
    Finished
}

public partial class RaceManager : Node
{
    public static RaceManager Instance { get; private set; }  // Para conveniencia como Autoload

    public List<Checkpoint> Checkpoints { get; private set; } = new();
    public List<RaceParticipant> Participants { get; private set; } = new();
    public int CheckpointCount => Checkpoints.Count;
    public RaceState State { get; private set; } = RaceState.Idle;
    public double RaceElapsedTime { get; private set; }
    public double CountdownEndsAt { get; private set; }
    
    [Export] public int TotalLaps { get; private set; } = 3;

    // Declaración de señales en Godot 4 con C#
    [Signal] public delegate void RaceStartedEventHandler(RaceManager manager, double timestamp);
    [Signal] public delegate void LapCompletedEventHandler(RaceParticipant participant, int lap, int totalLaps);
    [Signal] public delegate void RaceFinishedEventHandler(RaceParticipant participant, double time, int position);
    [Signal] public delegate void RacerEliminatedEventHandler(RaceParticipant participant);

    public override void _Ready()
    {
        Instance = this;
    }

    public void RegisterCheckpoint(Checkpoint cp)
    {
        if (!Checkpoints.Contains(cp))
        {
            Checkpoints.Add(cp);
            EnforceIndexOrder();
        }
    }

    private void EnforceIndexOrder()
    {
        // Ordena los checkpoints basándose en su propiedad Index asignada en el editor
        Checkpoints = Checkpoints.OrderBy(c => c.Index).ToList();
    }

    public void StartRace(IEnumerable<RaceParticipant> racers, int laps, double countdownSeconds)
    {
        if (Checkpoints.Count == 0)
        {
            GD.PrintErr("¡No se pueden iniciar la carrera! No hay checkpoints registrados.");
            return;
        }

        Participants = racers.ToList();
        TotalLaps = laps;

        foreach (var p in Participants)
        {
            // Asegurarnos de que el método RegisterRace exista en RaceParticipant, 
            // o inicializar según convenga. Desactivamos controles durante la cuenta regresiva.
            if (p.GetParent() is Node3D shipNode && shipNode.HasMethod("SetControlEnabled"))
            {
                shipNode.Call("SetControlEnabled", false);
            }
        }

        State = RaceState.Countdown;
        CountdownEndsAt = (Time.GetTicksMsec() / 1000.0) + countdownSeconds;
        
        EmitSignal(SignalName.RaceStarted, this, Time.GetTicksMsec() / 1000.0);
    }

    public override void _PhysicsProcess(double delta)
    {
        if (State == RaceState.Countdown)
        {
            double currentTime = Time.GetTicksMsec() / 1000.0;
            if (currentTime >= CountdownEndsAt)
            {
                ToRacing();
            }
            return;
        }

        if (State == RaceState.Racing)
        {
            RaceElapsedTime += delta;
            UpdateRankings();
        }
    }

    private void ToRacing()
    {
        State = RaceState.Racing;
        RaceElapsedTime = 0;

        foreach (var p in Participants)
        {
            // Habilitar los controles de las naves al terminar la cuenta regresiva
            Node3D ownerNode = p.GetParent() as Node3D;
            if (ownerNode != null)
            {
                var controller = ownerNode.GetNodeOrNull<Node3D>("ShipController") ?? ownerNode.FindChild("ShipController", true, false) as Node3D;
                if (controller != null && controller.HasMethod("set_ControlEnabled"))
                {
                    controller.Set("ControlEnabled", true);
                }
            }
        }
    }

    private void UpdateRankings()
    {
        // Lógica opcional para ordenar participantes por progreso (ProgressScore o Laps)
    }
}