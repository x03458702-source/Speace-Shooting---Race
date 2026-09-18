using Godot;
using SpaceShootingRace.Combat;
using SpaceShootingRace.Ships;

namespace SpaceShootingRace.Racing;

public partial class RaceParticipant : Node
{
    [Export] public string PilotName { get; set; } = "Piloto";

    private RaceManager _manager;

    public RaceManager Manager => _manager;
    public int TotalLaps { get; private set; }
    public int CheckpointCount => _manager?.CheckpointCount ?? 0;
    public int LapsCompleted { get; private set; }
    public int NextCheckpointIndex { get; private set; } = 1;
    public bool Finished { get; private set; }
    public bool Eliminated { get; private set; }
    public double FinishTime { get; private set; }
    public float ProgressScore { get; set; }
    public int CurrentPosition { get; set; } = 1;
    public ShipController Ship => GetParent() as ShipController;

    [Signal] public delegate void LapCompletedEventHandler(RaceParticipant participant, int lap, int totalLaps);
    [Signal] public delegate void RaceFinishedEventHandler(RaceParticipant participant, double time, int position);
    [Signal] public delegate void EliminatedEventHandler(RaceParticipant participant);

    public override void _Ready()
    {
        var damage = GetParent().GetNodeOrNull<ShipDamage>("DamageArea");
        if (damage != null)
            damage.Connect(ShipDamage.SignalName.ShipDestroyed, Callable.From(OnDestroyed));
    }

    public void Initialize(RaceManager manager, int totalLaps)
    {
        _manager = manager;
        TotalLaps = totalLaps;
        LapsCompleted = 0;
        NextCheckpointIndex = 1;
        Finished = false;
        Eliminated = false;
        FinishTime = 0.0;
        SetControl(false);

        var damage = GetParent().GetNodeOrNull<ShipDamage>("DamageArea");
        damage?.ResetLives();
    }

    public void SetControl(bool enabled)
    {
        if (Ship != null)
            Ship.SetControlEnabled(enabled);
    }

    public void OnCheckpointEntered(Checkpoint cp)
    {
        if (_manager == null || Finished || Eliminated)
            return;
        if (cp.Index != NextCheckpointIndex)
            return;

        if (NextCheckpointIndex == 0)
        {
            LapsCompleted++;
            EmitSignal(SignalName.LapCompleted, this, LapsCompleted, TotalLaps);
            if (LapsCompleted >= TotalLaps)
            {
                FinishRace();
                return;
            }
            NextCheckpointIndex = 1;
        }
        else
        {
            NextCheckpointIndex = (NextCheckpointIndex + 1) % CheckpointCount;
        }
    }

    private void FinishRace()
    {
        Finished = true;
        FinishTime = _manager.RaceElapsedTime;
        NextCheckpointIndex = 0;
        _manager.NotifyRaceFinished(this);
        EmitSignal(SignalName.RaceFinished, this, FinishTime, CurrentPosition);
    }

    private void OnDestroyed()
    {
        Eliminated = true;
        SetControl(false);
        EmitSignal(SignalName.Eliminated, this);
        _manager?.NotifyEliminated(this);
    }
}