using Godot;
using SpaceShootingRace.Ships;

namespace SpaceShootingRace.Combat;

public partial class ShipDamage : Area3D
{
    [Export] public int MaxLives { get; set; } = 3;
    [Export] public float InvulnerabilitySeconds { get; set; } = 1.5f;
    [Export] public float HitBounceFactor { get; set; } = 0.35f;
    [Export] public float CrashRecoverySeconds { get; set; } = 0.8f;
    [Export] public uint HazardLayerMask { get; set; } = 4u;

    public int Lives { get; private set; }
    public bool IsInvulnerable => Now() < _invulnerableUntil;

    private double _invulnerableUntil;

    [Signal] public delegate void HitTakenEventHandler(int remainingLives);
    [Signal] public delegate void ShieldAbsorbedEventHandler();
    [Signal] public delegate void ShipDestroyedEventHandler();

    public override void _Ready()
    {
        Lives = MaxLives;
        Monitoring = true;
        CollisionMask = HazardLayerMask;
        BodyEntered += OnBodyEntered;
    }

    private static double Now() => Time.GetTicksMsec() / 1000.0;

    public void ResetLives()
    {
        Lives = MaxLives;
        _invulnerableUntil = 0.0;
        Monitoring = true;
    }

    public void SetInvulnerableFor(double seconds)
    {
        _invulnerableUntil = Now() + seconds;
    }

    private void OnBodyEntered(Node3D body)
    {
        if (IsInvulnerable)
            return;
        TakeDamage(1);
    }

    public void TakeDamage(int amount)
    {
        if (IsInvulnerable || amount <= 0)
            return;

        Lives = Mathf.Max(0, Lives - amount);
        _invulnerableUntil = Now() + InvulnerabilitySeconds;
        EmitSignal(SignalName.HitTaken, Lives);

        if (GetParent() is ShipController ship)
        {
            ship.ApplyCrash(CrashRecoverySeconds);
            Vector3 vel = ship.LinearVelocity;
            if (vel.Length() > 1f)
                ship.LinearVelocity = -vel * HitBounceFactor;
        }

        if (Lives <= 0)
        {
            EmitSignal(SignalName.ShipDestroyed);
            Monitoring = false;
        }
    }
}