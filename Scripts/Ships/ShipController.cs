using Godot;

namespace SpaceShootingRace.Ships;

public partial class ShipController : RigidBody3D
{
    [Export] public ShipStats Stats { get; set; } = new ShipStats();
    [Export] public NodePath MeshNodePath { get; set; }
    [Export] public float InputDeadzone { get; set; } = 0.2f;

    [Export] public uint GroundLayerMask { get; set; } = 1u;
    [Export] public float RayLength { get; set; } = 60f;
    [Export] public float CruiseAltitude { get; set; } = 6f;
    [Export] public float AltitudeResponse { get; set; } = 3f;
    [Export] public float MaxAltitudeVelocity { get; set; } = 9f;
    [Export] public float LateralDamping { get; set; } = 1.8f;

    [Export] public float BoostCapacity { get; set; } = 1f;
    [Export] public float BoostConsumption { get; set; } = 0.55f;
    [Export] public float BoostRecovery { get; set; } = 0.3f;

    private Node3D _mesh;
    private float _inputThrottle;
    private float _inputSteer;
    private bool _inputBrake;
    private bool _inputBoost;
    private float _forwardSpeed;
    private float _boostEnergy = 1f;
    private bool _boosting;
    private float _crashRecoveryTimer;
    private float _altitudeVelocity;

    public bool ControlEnabled { get; private set; } = true;
    public bool IsGrounded { get; private set; }
    public bool IsBoosting => _boosting;
    public float BoostEnergy => _boostEnergy;
    public float CurrentSpeed => _forwardSpeed;
    public float SpeedRatio
    {
        get
        {
            if (Stats.MaxSpeed <= 0f) return 0f;
            return Mathf.Clamp(Mathf.Abs(_forwardSpeed) / Stats.MaxSpeed, 0f, 1f);
        }
    }
    public float ExtraAngularYaw { get; set; }

    public override void _Ready()
    {
        CanSleep = false;
        GravityScale = 0f;
        LinearDamp = Stats.LinearDamping;
        AngularDamp = Stats.AngularDamping;
        if (MeshNodePath != null)
            _mesh = GetNodeOrNull<Node3D>(MeshNodePath);
    }

    public void SetControlEnabled(bool enabled)
    {
        ControlEnabled = enabled;
        if (!enabled)
        {
            _inputThrottle = 0f;
            _inputSteer = 0f;
            _inputBrake = false;
            _inputBoost = false;
        }
    }

    public void SetInput(float throttle, float steer)
    {
        _inputThrottle = throttle;
        _inputSteer = steer;
        _inputBrake = false;
        _inputBoost = false;
    }

    public void ApplyCrash(float duration)
    {
        _crashRecoveryTimer = Mathf.Max(_crashRecoveryTimer, duration);
        _forwardSpeed *= 0.15f;
    }

    private void ReadInput()
    {
        if (!ControlEnabled) return;
        _inputThrottle = Input.GetActionStrength("throttle") - Input.GetActionStrength("reverse");
        _inputSteer = Input.GetActionStrength("steer_right") - Input.GetActionStrength("steer_left");
        _inputBrake = Input.IsActionPressed("brake");
        _inputBoost = Input.IsActionPressed("boost");
    }

    public override void _IntegrateForces(PhysicsDirectBodyState3D state)
    {
        float d = (float)state.Step;
        if (_crashRecoveryTimer > 0f)
            _crashRecoveryTimer -= d;

        ReadInput();
        Vector3 forward = -state.Transform.Basis.Z;

        UpdateHover(state);
        UpdateEngine(state, d, forward);
        UpdateBoost(d);
        UpdateSteering(state, d);
        UpdateVisuals(d);
    }

    private void UpdateHover(PhysicsDirectBodyState3D state)
    {
        Vector3 origin = state.Transform.Origin;
        var query = PhysicsRayQueryParameters3D.Create(
            origin, origin + Vector3.Down * RayLength, GroundLayerMask, null);
        var hit = GetWorld3D().DirectSpaceState.IntersectRay(query);

        float error;
        if (hit.Count > 0)
        {
            IsGrounded = true;
            float groundY = hit["position"].AsVector3().Y;
            error = groundY + Stats.HoverHeight - origin.Y;
        }
        else
        {
            IsGrounded = false;
            error = CruiseAltitude - origin.Y;
        }
        _altitudeVelocity = Mathf.Clamp(error * AltitudeResponse, -MaxAltitudeVelocity, MaxAltitudeVelocity);
    }

    private void UpdateEngine(PhysicsDirectBodyState3D state, float d, Vector3 forward)
    {
        bool recovering = _crashRecoveryTimer > 0f;
        float maxSpeed = Stats.MaxSpeed;
        float accel = Stats.Acceleration;
        if (_boosting)
        {
            maxSpeed *= Stats.BoostMultiplier;
            accel *= 1.5f;
        }
        if (recovering)
            maxSpeed *= 0.25f;

        float target = 0f;
        if (_inputThrottle > InputDeadzone)
            target = maxSpeed;
        else if (_inputThrottle < -InputDeadzone)
            target = Stats.ReverseSpeed;

        if (_forwardSpeed > target)
        {
            float dec = _inputBrake ? Stats.BrakeDeceleration : Stats.CoastDeceleration;
            _forwardSpeed = Mathf.MoveToward(_forwardSpeed, target, dec * d);
        }
        else
        {
            _forwardSpeed = Mathf.MoveToward(_forwardSpeed, target, accel * d);
        }

        Vector3 v = state.LinearVelocity;
        float fwd = v.Dot(forward);
        Vector3 rest = v - forward * fwd;
        rest.Y = 0f;
        rest *= Mathf.Exp(-LateralDamping * d);

        Vector3 newV = forward * _forwardSpeed + rest;
        newV.Y = _altitudeVelocity;
        state.LinearVelocity = newV;
    }

    private void UpdateBoost(float d)
    {
        if (ControlEnabled && _inputBoost && _boostEnergy > 0.01f)
        {
            _boosting = true;
            _boostEnergy = Mathf.Max(0f, _boostEnergy - BoostConsumption * d);
        }
        else
        {
            _boosting = false;
            _boostEnergy = Mathf.Min(BoostCapacity, _boostEnergy + BoostRecovery * d);
        }
    }

    private void UpdateSteering(PhysicsDirectBodyState3D state, float d)
    {
        float steer = Mathf.Abs(_inputSteer) < InputDeadzone ? 0f : _inputSteer;
        float factor = Mathf.Lerp(0.25f, 1f, SpeedRatio);
        float targetYaw = steer * Stats.SteeringSpeed * factor + ExtraAngularYaw;

        Vector3 ang = state.AngularVelocity;
        ang.Y = Mathf.Lerp(ang.Y, targetYaw, 1f - Mathf.Exp(-Stats.SteeringResponse * d));
        ang.X *= Mathf.Exp(-6f * d);
        ang.Z *= Mathf.Exp(-6f * d);
        state.AngularVelocity = ang;
    }

    private void UpdateVisuals(float d)
    {
        if (_mesh == null) return;
        float roll = -_inputSteer * Stats.MaxBankAngle * SpeedRatio;
        float pitch = Mathf.Clamp(_forwardSpeed / Stats.MaxSpeed, 0f, 1f) * 0.06f;
        _mesh.Rotation = new Vector3(pitch, 0f, roll);
    }
}