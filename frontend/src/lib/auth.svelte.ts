import { browser } from "$app/environment";
import { goto } from "$app/navigation";
import { api, type Account } from "./petring_api";

let user = $state<Account | null>(null);
let loading = $state<boolean>(true);

export const auth = {
  get user() {
    return user;
  },
  get loading() {
    return loading;
  },

  async check() {
    if (!browser) return;
    loading = true;
    try {
      user = await api.admin.me();
    } catch {
      user = null;
    } finally {
      loading = false;
    }
  },

  async login(username: string, password: string) {
    await api.admin.login(username, password);
    await this.check();
  },

  async logout() {
    await api.admin.logout();
    user = null;
    goto("/");
  },
};
