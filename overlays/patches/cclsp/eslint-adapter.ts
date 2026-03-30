import { logger } from '../../logger.js';
import type { LSPServerConfig } from '../../types.js';
import type { InitializeParams, ServerAdapter, ServerState } from '../types.js';

/**
 * Adapter for vscode-eslint-language-server.
 *
 * The eslint LSP server uses a pull model for configuration: it sends
 * workspace/configuration requests to the client instead of reading
 * initializationOptions directly. Without a handler, the server silently
 * produces no diagnostics.
 *
 * This adapter:
 * - Advertises workspace.configuration capability so the server sends requests
 * - Responds to workspace/configuration with settings from initializationOptions
 * - Injects workspaceFolder metadata the server needs to locate eslint configs
 * - Handles eslint-specific custom messages (confirmExecution, probeFailed, etc.)
 *
 * Reference: neovim/nvim-lspconfig lsp/eslint.lua
 */
export class EslintAdapter implements ServerAdapter {
  readonly name = 'eslint';

  matches(config: LSPServerConfig): boolean {
    return config.command.some(
      (c: string) =>
        c.includes('vscode-eslint-language-server') || c.includes('eslint-language-server')
    );
  }

  customizeInitializeParams(params: InitializeParams): InitializeParams {
    const capabilities =
      typeof params.capabilities === 'object' && params.capabilities !== null
        ? (params.capabilities as Record<string, unknown>)
        : {};

    const workspace =
      typeof capabilities.workspace === 'object' && capabilities.workspace !== null
        ? (capabilities.workspace as Record<string, unknown>)
        : {};

    // Advertise workspace/configuration support so the server sends pull requests
    const updatedCapabilities = {
      ...capabilities,
      workspace: {
        ...workspace,
        configuration: true,
      },
    };

    // Inject workspaceFolder into settings (like Neovim's before_init).
    // The eslint server uses this to scope config file resolution.
    const rootUri = params.rootUri;
    const rootName = rootUri.split('/').pop() || 'workspace';

    const existingOptions =
      typeof params.initializationOptions === 'object' && params.initializationOptions !== null
        ? (params.initializationOptions as Record<string, unknown>)
        : {};

    const existingSettings =
      typeof existingOptions.settings === 'object' && existingOptions.settings !== null
        ? (existingOptions.settings as Record<string, unknown>)
        : {};

    return {
      ...params,
      capabilities: updatedCapabilities,
      initializationOptions: {
        ...existingOptions,
        settings: {
          ...existingSettings,
          workspaceFolder: {
            uri: rootUri,
            name: rootName,
          },
        },
      },
    };
  }

  async handleRequest(method: string, params: unknown, state: ServerState): Promise<unknown> {
    if (method === 'workspace/configuration') {
      return this.handleWorkspaceConfiguration(params, state);
    }

    if (method === 'eslint/confirmESLintExecution') {
      // 4 = approved (matches the enum in vscode-eslint)
      return 4;
    }

    if (method === 'eslint/openDoc') {
      // Headless context -- acknowledge but don't open a browser
      const result = params as { url?: string } | null;
      if (result?.url) {
        logger.info(`[EslintAdapter] eslint/openDoc: ${result.url}\n`);
      }
      return {};
    }

    return Promise.reject(new Error(`Unhandled request: ${method}`));
  }

  handleNotification(method: string, params: unknown, _state: ServerState): boolean {
    if (method === 'eslint/probeFailed') {
      logger.warn('[EslintAdapter] ESLint probe failed -- eslint may not be installed.\n');
      return true;
    }

    if (method === 'eslint/noLibrary') {
      logger.warn('[EslintAdapter] Unable to find ESLint library.\n');
      return true;
    }

    if (method === 'eslint/noConfig') {
      logger.warn('[EslintAdapter] No ESLint configuration found.\n');
      return true;
    }

    return false;
  }

  /**
   * Respond to workspace/configuration requests.
   *
   * The server sends an array of ConfigurationItem objects, each with an
   * optional `section` and `scopeUri`. We return the eslint settings for
   * every requested item. Section "" means "give me everything".
   */
  private handleWorkspaceConfiguration(params: unknown, state: ServerState): unknown[] {
    const items = (params as { items?: Array<{ section?: string; scopeUri?: string }> })?.items;
    if (!Array.isArray(items)) {
      return [];
    }

    // Extract settings from initializationOptions -- this is what the user
    // configured in cclsp.json under initializationOptions.settings.
    const initOpts = state.config.initializationOptions;
    const settings =
      typeof initOpts === 'object' && initOpts !== null
        ? ((initOpts as Record<string, unknown>).settings ?? {})
        : {};

    return items.map((item) => {
      const section = item.section ?? '';

      if (section === '' || section === 'eslint') {
        // Return the full settings object
        return settings;
      }

      // For dotted sections like "eslint.validate", traverse into settings
      const parts = section.replace(/^eslint\./, '').split('.');
      let value: unknown = settings;
      for (const part of parts) {
        if (typeof value === 'object' && value !== null && part in (value as Record<string, unknown>)) {
          value = (value as Record<string, unknown>)[part];
        } else {
          return null;
        }
      }
      return value;
    });
  }
}
