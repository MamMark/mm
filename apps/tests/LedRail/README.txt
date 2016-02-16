Program used to build/test a component that implements the PowerRail interface.

The component that implements the interface keeps a refcount of clients requesting power.
When the refcount transitions from 0 -> 1 the power enable pin on the regulator
is set high. When it transitions back to 0 we lower the power enable pin.

For starters we'll actually light up an LED instead of manipulating the enable pin.

