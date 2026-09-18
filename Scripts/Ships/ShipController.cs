using Godot;

namespace SpaceShootingRace.Ships;

public partial class ShipController : RigidBody3D
{
    [Export] private ShipStats _stats;
    [Export] private NodePath _meshPath; // for banking visuals maybe

    private float _throttle;
    private float _steerInput;
    private bool _braking;
    private bool _boosting;
    private bool _controlEnabled = true;

    public float Throttle { get; private set; }
    public float CurrentSpeed { get; private set; }
    
    // Solucionado: Calcula el ratio de velocidad de forma segura evitando división por cero
    public float SpeedRatio => (_stats != null && _stats.MaxSpeed > 0f) ? Mathf.Clamp(CurrentSpeed / _stats.MaxSpeed, 0f, 1.5f) : 0f;
    
    // Solucionado: Se implementa el setter completo
    public bool ControlEnabled 
    { 
        get => _controlEnabled; 
        set 
        { 
            _controlEnabled = value; 
            if (!_controlEnabled) 
            {
                _throttle = 0f;
                _steerInput = 0f;
                _braking = false;
                _boosting = false;
            }
        } 
    }
    
    public override void _Ready()
    {
        if (_stats == null) _stats = new ShipStats();
        
        // Solucionado: Se asigna la masa desde _stats con un valor por defecto de respaldo
        Mass = _stats.Mass > 0f ? _stats.Mass : 1000f;
        LinearDamp = _stats.LinearDamping;
        AngularDamp = _stats.AngularDamping;
        CanSleep = false;
    }

    public override void _PhysicsProcess(double delta)
    {
        float d = (float)delta;
        CurrentSpeed = LinearVelocity.Length();

        UpdateThrottleFromInput();
        ApplyHoverForces(d);
        ApplySteering(d);
        ApplyEngineForce(d);
        ClampSpeed();
        ApplyBanking(d);
        UpdateVisuals();
    }

    private void UpdateThrottleFromInput()
    {
        // Puedes ajustar estas acciones según tu InputMap de Godot
        _throttle = Input.GetActionStrength("accelerate") - Input.GetActionStrength("brake");
        Throttle = _throttle;
        _braking = Input.IsActionPressed("brake");
        _boosting = Input.IsActionPressed("boost");
        _steerInput = Input.GetActionStrength("steer_right") - Input.GetActionStrength("steer_left");
    }

    private void ApplyHoverForces(float delta)
    {
        // Lógica de suspensión o gravedad personalizada (Pendiente de implementar según tu diseño)
    }

    private void ApplySteering(float delta)
    {
        // Lógica de giro (Pendiente de implementar)
    }

    private void ApplyEngineForce(float delta)
    {
        if (_stats != null)
        {
            float targetForce = _throttle * _stats.Acceleration;
            ApplyCentralForce(Transform.Basis.Z * -targetForce);
        }
    }

    private void ClampSpeed()
    {
        if (_stats == null) return;

        float maxLimit = _boosting ? _stats.MaxSpeed * _stats.BoostMultiplier : _stats.MaxSpeed;
        if (LinearVelocity.Length() > maxLimit)
        {
            LinearVelocity = LinearVelocity.Normalized() * maxLimit;
        }
    }

    private void ApplyBanking(float delta)
    {
        // Inclinación visual de la nave al girar (Pendiente de implementar)
    }

    private void UpdateVisuals()
    {
        // Actualización de partículas o mallas (Pendiente de implementar)
    }
}