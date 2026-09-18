using Godot;
using SpaceShootingRace.Ships;

namespace SpaceShootingRace.Camera;

public partial class FollowCamera : Camera3D
{
    [Export] public NodePath TargetPath { get; set; }
    [Export] public float Distance { get; set; } = 9f;
    [Export] public float Height { get; set; } = 3.2f;
    [Export] public float FollowSpeed { get; set; } = 6f;
    [Export] public float LookAhead { get; set; } = 2.5f;
    [Export] public float BaseFov { get; set; } = 70f;
    [Export] public float MaxFov { get; set; } = 78f;
    [Export] public float FovSpeed { get; set; } = 5f;

    private Node3D _target;

    public override void _Ready()
    {
        MakeCurrent();
        if (TargetPath != null)
            _target = GetNodeOrNull<Node3D>(TargetPath);
    }

    public override void _Process(double delta)
    {
        if (_target == null) return;
        float d = (float)delta;

        Vector3 forward = -_target.GlobalTransform.Basis.Z;
        Vector3 desired = _target.GlobalPosition - forward * Distance + Vector3.Up * Height;
        GlobalPosition = GlobalPosition.Lerp(desired, 1f - Mathf.Exp(-FollowSpeed * d));

        Vector3 lookAt = _target.GlobalPosition + forward * LookAhead;
        LookAt(lookAt, Vector3.Up);

        float ratio = (_target as ShipController)?.SpeedRatio ?? 0f;
        float targetFov = Mathf.Lerp(BaseFov, MaxFov, ratio);
        Fov = Mathf.Lerp(Fov, targetFov, 1f - Mathf.Exp(-FovSpeed * d));
    }
}