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
        </li>
      }
    </ul>
    $(com.form_new_user(super_admin))
  """


