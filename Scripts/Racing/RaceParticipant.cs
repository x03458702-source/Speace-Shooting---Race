using Godot;

namespace SpaceShootingRace.Races;

public partial class RaceParticipant : Node
{
    [Export] public string DisplayName { get; set; } = "Nave";

    // En Godot 4 con C#, las señales se declaran usando delegados con el atributo [Signal]
    [Signal] public delegate void LapCompletedEventHandler(int lap, int totalLaps);
    [Signal] public delegate void RaceFinishedEventHandler();

    public int LapsCompleted { get; private set; }
    public int NextCheckpointIndex { get; private set; }
    public float ProgressScore { get; set; } // para el ranking
    public bool Finished { get; private set; }
    public float FinishTime { get; private set; }

    private RaceManager _raceManager;

    public void Initialize(RaceManager rm, float positionAlongTrack)
    {
        _raceManager = rm;
        ProgressScore = positionAlongTrack;
        LapsCompleted = 0;
        NextCheckpointIndex = 0;
        Finished = false;
        FinishTime = 0f;
    }

    public void RegisterCheckpointEntry(Checkpoint cp)
    {
        if (Finished || _raceManager == null) return;

        if (cp.Index == NextCheckpointIndex)
        {
            NextCheckpointIndex = (NextCheckpointIndex + 1) % _raceManager.CheckpointCount;
            ProgressScore = LapsCompleted * 1000f + NextCheckpointIndex * 100f;
        }
    }

    public void RegisterFinishLineEntry()
    {
        if (Finished || _raceManager == null) return;

        LapsCompleted++;
        EmitSignal(SignalName.LapCompleted, LapsCompleted, _raceManager.TotalLaps);

        if (LapsCompleted >= _raceManager.TotalLaps)
        {
            Finished = true;
            FinishTime = (float)_raceManager.RaceElapsedTime;
            EmitSignal(SignalName.RaceFinished);
        }
    }
}