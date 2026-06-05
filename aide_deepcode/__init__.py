"""
AIDE — AI-Driven Development Automation for DeepCode

Usage:
    from workflows.plugins.aide import register_aide_plugins
    register_aide_plugins()  # Call once during DeepCode startup
"""


def register_aide_plugins(registry=None):
    """Register all AIDE plugins with the DeepCode PluginRegistry.

    All imports are lazy to avoid circular imports during DeepCode startup
    (this module is imported by workflows.plugins.__init__).

    Args:
        registry: DeepCode PluginRegistry instance. If None, uses the
                  default registry from workflows.plugins.
    """
    from .aide_spec_plugin import AideSpecPlugin
    from .aide_plan_plugin import AidePlanPlugin
    from .aide_implement_plugin import AideImplementPlugin
    from .aide_test_plugin import AideTestPlugin

    if registry is None:
        from workflows.plugins import get_default_registry
        registry = get_default_registry(auto_register=False)

    for plugin_cls in [AideSpecPlugin, AidePlanPlugin, AideImplementPlugin, AideTestPlugin]:
        plugin = plugin_cls()
        registry.register(plugin)

    return registry
