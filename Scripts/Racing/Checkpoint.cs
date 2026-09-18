using Godot;

namespace SpaceShootingRace.Racing;

public partial class Checkpoint : Area3D
{
    [Export] public int Index { get; set; }
    [Export] public bool IsFinishLine { get; set; }

    public override void _Ready()
    {
        BodyEntered += OnBodyEntered;
        var manager = GetNodeOrNull<RaceManager>("/root/RaceManager");
        manager?.RegisterCheckpoint(this);
    }

    private void OnBodyEntered(Node3D body)
    {
        var participant = body.GetNodeOrNull<RaceParticipant>("RaceParticipant");
        participant?.OnCheckpointEntered(this);
    }
}