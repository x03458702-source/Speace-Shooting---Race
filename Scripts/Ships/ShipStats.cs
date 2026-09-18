using Godot;

namespace SpaceShootingRace.Ships;

[GlobalClass, Tool]  // GlobalClass needs the script file; Tool not needed for resource
public partial class ShipStats : Resource
{
    [Export] public float MaxSpeed { get; set; } = 35f;
    [Export] public float ReverseSpeed { get; set; } = -12f;
    [Export] public float Acceleration { get; set; } = 24f;
    [Export] public float BrakeDeceleration { get; set; } = 60f;
    [Export] public float CoastDeceleration { get; set; } = 6f;
    [Export] public float SteeringSpeed { get; set; } = 2.4f;
    [Export] public float SteeringResponse { get; set; } = 6f;
    [Export] public float MaxBankAngle { get; set; } = 0.7f;
    [Export] public float HoverHeight { get; set; } = 3f;
    [Export] public float LinearDamping { get; set; } = 0.15f;
    [Export] public float AngularDamping { get; set; } = 1.5f;
    [Export] public float BoostMultiplier { get; set; } = 1.5f;
    [Export] public float TurnSpeedFactor { get; set; } = 1f;  // not used; skip
}