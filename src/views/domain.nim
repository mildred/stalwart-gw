import templates
import ../common
import ../db/users
import ./users as vusers

func domain*(com: CommonRequest, domain: string, users: seq[User], super_admin: bool): string = tmpli html"""
    <h2>Users List</h2>
    <ul>
      $for user in users {
        <li>
          $if user.domain_admin {
            <strong>
              <a href="$(com.prefix)/users/$(user.email)">$(user.email)</a>
            </strong>
            <em>($(user.email.domain) administrator)</em>
          }
          $else {
            <a href="$(com.prefix)/users/$(user.email)">$(user.email)</a>
          }
          $if user.super_admin {
            <em>(super admin)</em>
          }
          $if user.num_aliases > 0 {
            <em>(alias)</em>
          }
          $if user.catchall {
            <em>(catch all)</em>
          }
          $else {
            <form method="POST" action="$(com.prefix)/users/$(user.email)" role="none">
              <input type="hidden" name="catchall" value="1" />
              <input type="submit" value="make catch-all" role="link" />
            </form>
          }
        </li>
      }
    </ul>
    $(com.form_new_user(super_admin))
    $(com.form_new_alias())
  """


