using Godot;
using SpaceShootingRace.Ships;

namespace SpaceShootingRace.Cameras;

public partial class FollowCamera : Camera3D
{
    [Export] public NodePath TargetPath { get; set; }
    [Export] public float Distance { get; set; } = 8f;
    [Export] public float Height { get; set; } = 3.5f;
    [Export] public float FollowSpeed { get; set; } = 8f;
    [Export] public float RotationSpeed { get; set; } = 6f;
    [Export] public float FovMin { get; set; } = 70f;
    [Export] public float FovMax { get; set; } = 78f;

    private Node3D _target;
    private ShipController _shipController;

    public override void _Ready()
    {
        if (!TargetPath.IsEmpty)
        {
            _target = GetNodeOrNull<Node3D>(TargetPath);
            if (_target is ShipController ship)
            {
                _shipController = ship;
            }
            else if (_target != null)
            {
                _shipController = _target.GetNodeOrNull<ShipController>("ShipController") 
                                  ?? _target.FindChild("ShipController", true, false) as ShipController;
            }
        }
    }

    public override void _PhysicsProcess(double delta)
    {
        if (_target == null) return;

        float dt = (float)delta;

        // En Godot, el frente de un objeto 3D suele ser el eje -Z
        Vector3 targetForward = -_target.GlobalTransform.Basis.Z;

        // Posición deseada detrás de la nave y elevada
        Vector3 desiredPos = _target.GlobalPosition - (targetForward * Distance) + (Vector3.Up * Height);

        // Movimiento suave de la cámara usando amortiguación exponencial independiente del framerate
        GlobalPosition = GlobalPosition.Lerp(desiredPos, 1.0f - Mathf.Exp(-FollowSpeed * dt));

        // Punto hacia donde debe mirar la cámara (ligeramente elevado respecto al centro de la nave)
        Vector3 lookTarget = _target.GlobalPosition + (Vector3.Up * 1.0f);

        // Creamos la transformación orientada al objetivo y la interpolamos suavemente
        Transform3D targetTransform = GlobalTransform.LookingAt(lookTarget, Vector3.Up);
        GlobalTransform = GlobalTransform.InterpolateWith(targetTransform, 1.0f - Mathf.Exp(-RotationSpeed * dt));

        // Ajuste dinámico del FOV basado en la velocidad de la nave (SpeedRatio)
        if (_shipController != null)
        {
            float targetFov = Mathf.Lerp(FovMin, FovMax, _shipController.SpeedRatio);
            Fov = Mathf.Lerp(Fov, targetFov, 5.0f * dt);
        }
    }
}