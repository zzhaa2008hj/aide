"""
AIDE — AI-Driven Development Automation for DeepCode

Usage:
    from aide_deepcode import register_aide_plugins
    register_aide_plugins()  # Call once during DeepCode startup
"""

from .aide_spec_plugin import AideSpecPlugin
from .aide_plan_plugin import AidePlanPlugin
from .aide_implement_plugin import AideImplementPlugin
from .aide_test_plugin import AideTestPlugin


def register_aide_plugins(registry=None):
    """Register all AIDE plugins with the DeepCode PluginRegistry.

    Args:
        registry: DeepCode PluginRegistry instance. If None, uses the
                  default registry from workflows.plugins.
    """
    if registry is None:
        from workflows.plugins import get_default_registry
        registry = get_default_registry(auto_register=False)

    for plugin_cls in [AideSpecPlugin, AidePlanPlugin, AideImplementPlugin, AideTestPlugin]:
        plugin = plugin_cls()
        registry.register(plugin)

    return registry
