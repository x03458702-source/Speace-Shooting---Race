using Godot;

namespace SpaceShootingRace.Combat;

public enum PowerUpType
{
    None,
    EscudoEspacial,
    CanonLaser,
    BombaArea,
    AceiteEspacial
}

public partial class PowerUpComponent : Node
{
    [Export] public PowerUpType CurrentPowerUp { get; private set; } = PowerUpType.None;
    [Export] public int CannonCharges { get; private set; } = 0;
    [Export] public bool IsShieldActive { get; private set; } = false;
    [Export] public float ShieldDuration { get; set; } = 8.0f;

    [Signal] public delegate void PowerUpChangedEventHandler(int type, int charges);
    [Signal] public delegate void ShieldStateChangedEventHandler(bool active);

    private double _shieldTimeLeft = 0;

    public bool StorePowerUp(PowerUpType type)
    {
        if (CurrentPowerUp != PowerUpType.None) return false;

        CurrentPowerUp = type;
        if (type == PowerUpType.CanonLaser)
        {
            CannonCharges = 3;
        }

        EmitSignal(SignalName.PowerUpChanged, (int)CurrentPowerUp, CannonCharges);
        return true;
    }

    public void UsePowerUp()
    {
        if (CurrentPowerUp == PowerUpType.None) return;

        switch (CurrentPowerUp)
        {
            case PowerUpType.EscudoEspacial:
                ActivateShield();
                CurrentPowerUp = PowerUpType.None;
                break;
            case PowerUpType.CanonLaser:
                CannonCharges--;
                if (CannonCharges <= 0) CurrentPowerUp = PowerUpType.None;
                break;
            case PowerUpType.BombaArea:
                CurrentPowerUp = PowerUpType.None;
                break;
            case PowerUpType.AceiteEspacial:
                CurrentPowerUp = PowerUpType.None;
                break;
        }

        EmitSignal(SignalName.PowerUpChanged, (int)CurrentPowerUp, CannonCharges);
    }

    public void ActivateShield()
    {
        IsShieldActive = true;
        _shieldTimeLeft = ShieldDuration;
        EmitSignal(SignalName.ShieldStateChanged, true);
    }

    public void DeactivateShield()
    {
        IsShieldActive = false;
        _shieldTimeLeft = 0;
        EmitSignal(SignalName.ShieldStateChanged, false);
    }

    public override void _Process(double delta)
    {
        if (IsShieldActive)
        {
            _shieldTimeLeft -= delta;
            if (_shieldTimeLeft <= 0)
            {
                DeactivateShield();
            }
        }
    }
}
