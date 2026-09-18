using Godot;

namespace SpaceShootingRace.Ships;

public partial class ShipStats : Resource
{
    [Export] public float MaxSpeed { get; set; } = 35f;
    [Export] public float ReverseSpeed { get; set; } = -12f;
    [Export] public float Acceleration { get; set; } = 24f;
    [Export] public float BrakeDeceleration { get; set; } = 55f;
    [Export] public float CoastDeceleration { get; set; } = 6f;
    [Export] public float SteeringSpeed { get; set; } = 2.4f;
    [Export] public float SteeringResponse { get; set; } = 6f;
    [Export] public float MaxBankAngle { get; set; } = 0.7f;
    [Export] public float HoverHeight { get; set; } = 3f;
    [Export] public float LinearDamping { get; set; } = 0.15f;
    [Export] public float AngularDamping { get; set; } = 1.5f;
    [Export] public float BoostMultiplier { get; set; } = 1.5f;
}