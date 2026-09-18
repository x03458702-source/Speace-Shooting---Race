using Godot;

namespace SpaceShootingRace.Races;

public partial class Checkpoint : Area3D
{
    [Export] public int Index { get; set; }
    [Export] public bool IsFinishLine { get; set; }

    public override void _Ready()
    {
        BodyEntered += OnBodyEntered;
        // Asegurar que las capas y máscaras de colisión estén configuradas en el editor
        Monitoring = true;
    }

    private void OnBodyEntered(Node3D body)
    {
        // Buscamos el componente RaceParticipant en el cuerpo que entra o en sus hijos
        RaceParticipant participant = body.GetNodeOrNull<RaceParticipant>("RaceParticipant") 
                                      ?? body.FindChild("RaceParticipant", true, false) as RaceParticipant;

        if (participant != null)
        {
            if (IsFinishLine)
            {
                participant.RegisterFinishLineEntry();
            }
            else
            {
                participant.RegisterCheckpointEntry(this);
            }
        }
    }
}