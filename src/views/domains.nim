import templates
import ../common

func domains*(com: CommonRequest, my_domain: string, domains: seq[string]): string = tmpli html"""
    $if domains.len > 0 {
      <ul>
        $for domain in domains {
          <li>
            <a href="$(com.prefix)/domains/$domain">$domain</a>
            $if domain == my_domain {
              <em>(manager)</em>
            }
          </li>
        }
      </ul>
    }
    $else {
      <ul>
        <li>$my_domain <em>(member)</em></li>
      </ul>
    }
  """


