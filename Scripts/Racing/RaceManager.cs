using System.Collections.Generic;
using System.Linq;
using Godot;

namespace SpaceShootingRace.Racing;

public partial class RaceManager : Node
{
    public static RaceManager Instance { get; private set; }

    private readonly List<Checkpoint> _checkpoints = new();
    private readonly List<RaceParticipant> _participants = new();

    public int CheckpointCount => _checkpoints.Count;
    public RaceState State { get; private set; } = RaceState.Idle;
    public double RaceElapsedTime { get; private set; }
    public int TotalLaps { get; private set; } = 3;
    private double _countdownUntil;

    [Signal] public delegate void RaceStartedEventHandler(RaceManager manager);
    [Signal] public delegate void RaceFinishedEventHandler(RaceManager manager);

    public override void _Ready()
    {
        Instance = this;
    }

    public override void _ExitTree()
    {
        if (Instance == this)
            Instance = null;
    }

    public void RegisterCheckpoint(Checkpoint cp)
    {
        _checkpoints.RemoveAll(c => !IsInstanceValid(c));
        if (!_checkpoints.Contains(cp))
        {
            _checkpoints.Add(cp);
            _checkpoints.Sort((a, b) => a.Index.CompareTo(b.Index));
        }
    }

    public void StartRace(IEnumerable<RaceParticipant> participants, int totalLaps, double countdownSeconds)
    {
        _checkpoints.RemoveAll(c => !IsInstanceValid(c));
        _participants.RemoveAll(p => !IsInstanceValid(p));
        _participants.Clear();
        _participants.AddRange(participants);

        TotalLaps = Mathf.Max(1, totalLaps);
        foreach (var p in _participants)
            p.Initialize(this, TotalLaps);

        State = RaceState.Countdown;
        _countdownUntil = Time.GetTicksMsec() / 1000.0 + countdownSeconds;
        RaceElapsedTime = 0.0;
        EmitSignal(SignalName.RaceStarted, this);
    }

    public override void _PhysicsProcess(double delta)
    {
        if (State == RaceState.Countdown)
        {
            if (Time.GetTicksMsec() / 1000.0 >= _countdownUntil)
            {
                State = RaceState.Racing;
                RaceElapsedTime = 0.0;
                foreach (var p in _participants)
                    p.SetControl(true);
            }
            return;
        }

        if (State != RaceState.Racing)
            return;

        RaceElapsedTime += delta;
        UpdateProgress();
        UpdateRankings();

        if (_participants.All(p => p.Finished || p.Eliminated))
        {
            State = RaceState.Finished;
            EmitSignal(SignalName.RaceFinished, this);
        }
    }

    private void UpdateProgress()
    {
        foreach (var p in _participants)
        {
            if (p.Finished || p.Eliminated)
                continue;

            int n = CheckpointCount;
            if (n == 0)
            {
                p.ProgressScore = p.LapsCompleted;
                continue;
            }

            int passed = p.NextCheckpointIndex == 0 ? n - 1 : p.NextCheckpointIndex - 1;
            int nextIdx = p.NextCheckpointIndex % n;
            Vector3 shipPos = p.Ship?.GlobalPosition ?? Vector3.Zero;
            float dist = shipPos.DistanceTo(_checkpoints[nextIdx].GlobalPosition);
            float frac = 1f - Mathf.Clamp(dist / 80f, 0f, 0.95f);
            p.ProgressScore = p.LapsCompleted * (n + 1) + passed + frac;
        }
    }

    private void UpdateRankings()
    {
        int pos = 1;
        foreach (var p in _participants.Where(x => x.Finished).OrderBy(x => x.FinishTime))
            p.CurrentPosition = pos++;
        foreach (var p in _participants.Where(x => !x.Finished && !x.Eliminated).OrderByDescending(x => x.ProgressScore))
            p.CurrentPosition = pos++;
        foreach (var p in _participants.Where(x => x.Eliminated))
            p.CurrentPosition = pos;
    }

    public void NotifyRaceFinished(RaceParticipant p)
    {
        UpdateRankings();
        GD.Print($"[Race] {p.PilotName} finalizó en posición {p.CurrentPosition} con {p.FinishTime:F2}s");
    }

    public void NotifyEliminated(RaceParticipant p)
    {
        UpdateRankings();
        GD.Print($"[Race] {p.PilotName} fue eliminado");
    }
}