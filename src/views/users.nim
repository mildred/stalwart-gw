import templates
import ../common

func form_new_user*(com: CommonRequest, super_admin: bool): string = tmpli html"""
    <article id="h-add-new-user">
      <header>
        <h2>Add new user</h2>
      </header>
      <form method="post" action="$(com.prefix)/users">
        <input type="email"    name="email"     placeholder="E-mail" />
        <input type="password" name="password1" placeholder="password" />
        <input type="password" name="password2" placeholder="password (confirmation)" />
        $if super_admin {
          <label>
            <input type="checkbox" name="super_admin" value="1" />
            <span>super admin</span>
          </label>
        }
        <label>
          <input type="checkbox" name="domain_admin" value="1" />
          <span>domain admin</span>
        </label>
        <input type="submit" value="Add user" />
      </form>
    </article>
  """

func form_new_alias*(com: CommonRequest): string = tmpli html"""
    <article id="h-add-new-alias">
      <header>
        <h2>Add new alias</h2>
      </header>
      <form method="post" action="$(com.prefix)/users">
        <input type="email"    name="email"     placeholder="Alias e-mail" />
        <input type="email"    name="alias"     placeholder="Redirection e-mail" />
        <input type="submit" value="Add alias" />
      </form>
    </article>
  """

func view_users*(com: CommonRequest, super_admin: bool): string = tmpli html"""
  $if super_admin {
    $(com.form_new_user(super_admin))
    $(com.form_new_alias())
  }
  """


