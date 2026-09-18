using Godot;

namespace SpaceShootingRace.Ships;

public partial class ShipDamage : Area3D // Área en la nave que detecta cuerpos peligrosos
{
    [Export] public int MaxLives { get; set; } = 3;
    public int Lives { get; private set; }

    [Export] public float InvulnerabilityTime { get; set; } = 1.5f;
    [Export] public float HitImpulse { get; set; } = 10f;

    // Declaración de señales en Godot 4 con C#
    [Signal] public delegate void HitTakenEventHandler(int currentLives);
    [Signal] public delegate void ShipDestroyedEventHandler();

    private bool _isInvulnerable = false;

    public override void _Ready()
    {
        Lives = MaxLives;
        BodyEntered += OnBodyEntered;
        Monitoring = true; // Asegurarnos de que el Area3D esté monitoreando colisiones
    }

    private void OnBodyEntered(Node3D body)
    {
        if (_isInvulnerable || Lives <= 0) return;

        // Aquí puedes agregar un filtro adicional si lo deseas, por ejemplo: 
        // if (body.IsInGroup("Hazards")) { ... }

        TakeDamage(1);

        // Aplicar rebote si el nodo padre de esta área es un RigidBody3D
        if (GetParent() is RigidBody3D rb)
        {
            Vector3 bounceDir = (rb.GlobalPosition - body.GlobalPosition).Normalized();
            rb.ApplyCentralImpulse(bounceDir * HitImpulse);
        }
    }

    public void TakeDamage(int amount)
    {
        if (_isInvulnerable || Lives <= 0) return;

        Lives = Mathf.Clamp(Lives - amount, 0, MaxLives);
        EmitSignal(SignalName.HitTaken, Lives);

        if (Lives <= 0)
        {
            EmitSignal(SignalName.ShipDestroyed);
            // Aquí puedes añadir lógica adicional al destruirse, ej: QueueFree()
        }
        else
        {
            StartInvulnerability();
        }
    }

    private async void StartInvulnerability()
    {
        _isInvulnerable = true;
        // Creamos un temporizador asíncrono para gestionar el tiempo de invulnerabilidad
        await ToSignal(GetTree().CreateTimer(InvulnerabilityTime), SceneTreeTimer.SignalName.Timeout);
        _isInvulnerable = false;
    }
}