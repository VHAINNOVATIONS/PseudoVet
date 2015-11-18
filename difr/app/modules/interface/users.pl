#!/usr/bin/perl
use HTML::Template;

my $function=$g->controller(
  "key"=>'action',
  "default_key"=>'view',
  "default_function"=>'view',
  "function"=>{
    "new"=>'editor',
    "add"=>'add',
    "edit"=>'editor',
    "delete"=>'del',
    "update"=>'update',
    "set_module_access"=>'set_mod',
    "list"=>'view',
    "roles"=>'roles',
    "groups"=>'groups'
  },
); &$function;

1; # end module

sub add{
  $rv=$g->{dbh}->selectrow_array("select username from interface_users where username=\"$g->{username}\"");
  # insert user into user table if it doesn't already exist
  unless($rv eq $g->{username}){
    $sth=$g->{dbh}->do(
    "insert into interface_users values(
    '$g->{username}','$g->{active}','$g->{email}','$g->{theme}','$g->{timeout}',md5('$g->{password}') )");
    
    # add user demographics to interface_user_demographics table
    $sth=$g->{dbh}->do("insert into interface_user_demographics values('$g->{username}','$g->{salutation}','$g->{firstname}',
    '$g->{middle}',\"$g->{lastname}\",'$g->{suffix}',\"$g->{jobtitle}\",\"$g->{company}\",\"$g->{department}\",\"$g->{phone}\",
    \"$g->{addressline1}\",\"$g->{addressline2}\",\"$g->{city}\",\"$g->{stateprovince}\",\"$g->{postalcode}\",\"$g->{country}\")");
    #'$g->{fname}','$g->{middle}','$g->{lname}','$g->{suffix}','$g->{title}',
    #'$g->{service}','$g->{section}','$g->{ext}','$g->{pager}','$g->{cell}',

    # add user entry into module_users
    $sth=$g->{dbh}->prepare("show fields from interface_module_users"); $sth->execute();
    my $j=0; my @members1=("\"$g->{username}\"");
    while(my @row=$sth->fetchrow_array()){if($j>0){push(@members1,NULL);}$j++;}
    my $cmd1=join(",",@members1); $sth=$g->{dbh}->do("insert into interface_module_users values($cmd1)");
    msg("insert into interface_module_users values($cmd1)");

    $g->{dbh}->do("insert into interface_module_access values('$g->{username}','interface_preferences',NULL,NULL)");

    $g->{dbh}->do("update interface_module_users set interface_users=\"false\",
		   interface_sessions=\"false\", rcs_personnel=\"true\", rcs_studies=\"true\",
		   rcs_notifications=\"true\", rcs_settings=\"false\", rcs_alerts=\"false\",
		   rcs_projects=\"true\", rcs_reports=\"true\"
       where username=\"$g->{username}\"");
    view();
  }
  else{
    msg("The user you are trying to add, $g->{username}, already exists.");
    editor();
  }
}

sub update{
  $rv=$g->{dbh}->do(
    "update interface_user_demographics
     set salutation=\"$g->{salutation}\",firstname=\"$g->{firstname}\",middle=\"$g->{middle}\",lastname=\"$g->{lastname}\",suffix=\"$g->{suffix}\",
     jobtitle=\"$g->{jobtitle}\",company=\"$g->{company}\",department=\"$g->{department}\",phone=\"$g->{phone}\",
     addressline1=\"$g->{addressline1}\",addressline2=\"$g->{addressline2}\",city=\"$g->{city}\",stateprovince=\"$g->{stateprovince}\",
     postalcode=\"$g->{postalcode}\",country=\"$g->{country}\"
     where username=\"$g->{username}\""
  );
  
  $rv=$g->{dbh}->do(
    "update interface_users set active='$g->{active}',email='$g->{email}',theme='$g->{theme}',
     timeout='$g->{timeout}',password=md5('$g->{password}')
     where username='$g->{username}'"
  );
#  # create disabled account
#  $g->{dbh}->do("insert into interface_clients values('$g->{username}','false','$g->{email}',md5('$g->{passwordx}'));");
#  $g->{dbh}->do("insert into interface_user_demographics values(
#		'$g->{username}','$g->{salutation}','$g->{firstname}','$g->{middle}','$g->{lastname}','$g->{suffix}',
#		'$g->{jobtitle}','$g->{company}','$g->{department}','$g->{phone}','$g->{addressline1}','$g->{addressline2}',
#		'$g->{city}','$g->{stateprovince}','$g->{postalcode}','$g->{country}')");
  
  editor();
}

sub set_mod{
  my $m=$g->{dbh}->selectcol_arrayref("select name from interface_modules");
  foreach $mod (@{$m}){
    print "\n<!-- iterating through access to: $mod ";
    if($g->{$mod} eq 'true'){ print "~it was passed -->\n";
      my $u=$g->{dbh}->selectrow_array("select username from interface_module_access where module='$mod' and username='$g->{username}'");
      if($u ne $g->{username}){$g->{dbh}->do("insert into interface_module_access values('$g->{username}','$mod',NULL,NULL)");}
    }
    else{
      print "~not passed [$g->{$mod}] -->\n";
      $g->{dbh}->do("delete from interface_module_access where module='$mod' and username='$g->{username}'");
    }
  }
  editor();
}

#sub set_mod{
#  # iterate through module_user fields
#  $sth=$g->{dbh}->prepare("show fields from interface_module_users"); $sth->execute();
#  while(my ($field)=$sth->fetchrow_array()){
#      unless($field eq "username"){
#        unless($g->{$field} eq "true"){$g->{$field}="false";}
#        $g->{dbh}->do("update interface_module_users set $field='$g->{$field}' where username='$g->{uname}'");
#  }  }
#  editor();
#}

sub del{
  unless($g->{confirmation} eq "true"){
    msg("User Deletion Confirmation");
    print $g->{CGI}->p("Are you sure you want to delete '<b><em>$g->{username}</em></b>' from <b><em>$g->{appname}</em></b>"),
    $g->{CGI}->br,
    $g->{CGI}->p("If you click 'Yes', all of their settings will be expunged and they will no longer be able to access the <b><em>$g->{appname}</em></b> application."),
    $g->{CGI}->br,
    $g->{CGI}->start_form(),
    $g->{CGI}->hidden({-name=>"action", -value=>"delete",-override=>"1"}),
    $g->{CGI}->hidden({-name=>"confirmation", -value=>"true",-override=>"1"}),
    $g->{CGI}->hidden({-name=>"username", -value=>"$g->{username}",-override=>"1"}),
    $g->{CGI}->h2({-align=>"center"},
      $g->{CGI}->submit("Delete '$g->{username}' from $g->{appname}"),
      $g->{CGI}->button({-value=>"Cancel",-onClick=>"location.href='$g->{scriptname}'"}),
    ),
    $g->{CGI}->end_form;
  }
  else{
    msg("User Deletion Confirmed");
    $sth=$g->{dbh}->do("delete from interface_users where username=\"$g->{username}\"");
    $sth=$g->{dbh}->do("delete from interface_user_demographics where username=\"$g->{username}\"");
    $sth=$g->{dbh}->do("delete from interface_module_users where username=\"$g->{username}\"");
    $sth=$g->{dbh}->do("delete from interface_module_access where username=\"$g->{username}\"");
    print $g->{CGI}->p("'<b><em>$g->{username}</em></b>' has been deleted from <b><em>$g->{appname}</em></b>"),
    $g->{CGI}->br,
    $g->{CGI}->p("All of their settings have been expunged and they will no longer be able to access the <b><em>$g->{appname}</em></b> application."),
    $g->{CGI}->h2({-align=>"center"},
      $g->{CGI}->button({-value=>"Continue",-onClick=>"location.href='$g->{scriptname}'"}),
    );
    $g->event("users","$g->{sys_username} deleted '$g->{username}'");
  }
}

sub editor{
  my @salutations=(" ","Mr.","Mrs.","Ms.","Dr.","Prof.","Rev","Sir","Dame","Sri");
  my @suffixes=(' ','Jr','Sr','II','III','IV','Esq.');
  my @countries=countries();

  print $g->{CGI}->div({-id=>"navlinks"},$g->{CGI}->a({-href=>"$g->{scriptname}"},"Select A Differenct Record"),);

  my $query_fields="interface_users.username,interface_users.active,interface_users.email,interface_users.theme,interface_users.timeout,
  md5(interface_users.password),
  interface_user_demographics.salutation,interface_user_demographics.firstname,interface_user_demographics.middle,interface_user_demographics.lastname,interface_user_demographics.suffix,
  interface_user_demographics.jobtitle,interface_user_demographics.company,
  interface_user_demographics.department,interface_user_demographics.phone,interface_user_demographics.addressline1,
  interface_user_demographics.addressline2,interface_user_demographics.city,interface_user_demographics.stateprovince,interface_user_demographics.postalcode,
  interface_user_demographics.country";

  my($username,$active,$email,$theme,$timeout,$password,$salutation,$firstname,$middle,$lastname,$suffix,
     $jobtitle,$company,$department,$phone,$addressline1,$addressline2,$city,$stateprovince,$postalcode,$country);

  #my($username,$fname,$m,$lname,$suffix,$title,$service,$ext,$pager,$cell,$active,$email,$theme,$timeout,$pword);
  #my $query_fields="username,fname,mi,lname,suffix,title,service,section,ext,pager,cell,active,email,theme,timeout,md5(password)";

  if($g->{action} eq "new"){
    $g->{action}="add"; print $g->{CGI}->h2({-align=>"center"},"User Creator");
  }
  elsif($g->{action} eq "edit" or $g->{action} eq "update" or $g->{action} eq "set_module_access"){
    $g->{action}="update";
    ($username,$active,$email,$theme,$timeout,$password,$salutation,$firstname,$middle,$lastname,$suffix,
     $jobtitle,$company,$department,$phone,$addressline1,$addressline2,$city,$stateprovince,$postalcode,$country)=
    $g->{dbh}->selectrow_array(
      "select $query_fields from interface_users
	left join interface_user_demographics on interface_users.username=interface_user_demographics.username
	where interface_users.username=\"$g->{username}\"");
  }
#        # build empty form
#        print "    <div class=\"row\">\n";
#        print "      <form action=\"$g->{scriptname}\" method=\"get\">\n";
#        print "        <input type='hidden' name='function' value='$g->{function}' override>\n";
#        print "        <input type='hidden' name='action' value='add'>\n";
#        print "        <input type='hidden' name='mode' value='insert'>\n";
#        print "        <div class=\"col-xs-6\">\n";
#        foreach $field (@fields){
#          if($field eq "$primary_id"){ # hidden
#            # this is a new entry set to zero
#            $g->{$field}=0;
#            print "        <input type='hidden' name='$field' value='$g->{$field}'>\n";
#          }
#          else{ # not hidden
#            print "        <div class=\"form-group\">\n";
#            print "          <label for=\"$field\">".$g->tc($field)."</label>\n";
#            print "          <input type=\"text\" class=\"form-control\" name=\"$field\" placeholder=\"".$g->tc($field)."\">\n";
#            print "        </div>\n";
#          }        
#        }
        print "      <button type=\"submit\" class=\"btn btn-default\">Submit</button>\n";
        print "      </div>\n";
        print "    </form>\n";
        print "  </div>\n";




  print $g->{CGI}->startform({-action=>"$g->{scriptname}",-method=>"GET"}),
  $g->{CGI}->hidden({-name=>"active",-value=>"true"}),
  $g->{CGI}->hidden({-name=>"action",-value=>"$g->{action}",-override=>1}),
  $g->{CGI}->h3("User Account Information"),
  qq(\n<div id='record'><div id="floatright">),
  $g->{CGI}->submit("Save Record"),
  qq(\n</div>\n),
  $g->{CGI}->label({-for=>"username"},"Username"),$g->{CGI}->textfield({-name=>"username",-size=>"12",-value=>"$username",-override=>1}),
  $g->{CGI}->label({-for=>"active"},"Account Active?"),$g->{CGI}->popup_menu({-name=>"active",-size=>"1",-default=>"$active",-values=>["Active"=>'active','False'=>'false'],-override=>1}),
  $g->{CGI}->label({-for=>"password"},"Password"),$g->{CGI}->password_field({-name=>"password",-size=>"15",-value=>"$password",-override=>1}),
  $g->{CGI}->label({-for=>"timeout"},"Timeout"),$g->{CGI}->textfield({-name=>"timeout",-size=>"3",-value=>"$timeout",-override=>1}),
  $g->{CGI}->label({-for=>"theme"},"Theme"),$g->{CGI}->popup_menu({-name=>"theme",-size=>"1",-default=>"$theme",-values=>["portal","default"],-override=>1}),
  $g->{CGI}->br(),
  #$g->{CGI}->label({-for=>"jobtitle"},"Title"),$g->{CGI}->textfield({-name=>"jobtitle",-size=>"5",-value=>"$jobtitle",-override=>1}),
  $g->{CGI}->label({-for=>"salutation"},"Salutation"),$g->{CGI}->popup_menu({-name=>"salutation",-default=>"$salutation",-values=>\@salutations,-override=>1}),
  $g->{CGI}->label({-for=>"firstname"},"Firstname"),$g->{CGI}->textfield({-name=>"firstname",-size=>"12",-value=>"$firstname",-override=>1}),
  $g->{CGI}->label({-for=>"middle"},"INI"),$g->{CGI}->textfield({-name=>"middle",-size=>"3",-value=>"$middle",-override=>1}),
  $g->{CGI}->label({-for=>"lastname"},"Lastname"),$g->{CGI}->textfield({-name=>"lastname",-size=>"25",-value=>"$lastname",-override=>1}),
  $g->{CGI}->label({-for=>"suffix"},"Suffix"),$g->{CGI}->popup_menu({-name=>"suffix",-default=>"$suffix",-values=>\@suffixes,-override=>1}),
  $g->{CGI}->br(),
  $g->{CGI}->label({-for=>"email"},"Email"),$g->{CGI}->textfield({-name=>"email",-size=>"30",-value=>"$email",-override=>1}),
  $g->{CGI}->label({-for=>"phone"},"Phone"),$g->{CGI}->textfield({-name=>"phone",-value=>"$phone",-override=>1}),
  $g->{CGI}->label({-for=>"department"},"Department"),$g->{CGI}->textfield({-name=>"department",-value=>"$department",-override=>1}),
  $g->{CGI}->br(),
  $g->{CGI}->label({-for=>"jobtitle"},"Job Title"),$g->{CGI}->textfield({-name=>"jobtitle",-value=>"$jobtitle",-override=>1,-size=>30}),
  $g->{CGI}->label({-for=>"company"},"Company"),$g->{CGI}->textfield({-name=>"company",-value=>"$company",-override=>1,-size=>50}),
  $g->{CGI}->br(),
  $g->{CGI}->label({-for=>"addressline1"},"Address Line 1"),$g->{CGI}->textfield({-name=>"addressline1",-value=>"$addressline1",-override=>1,-size=>100}),
  $g->{CGI}->br(),
  $g->{CGI}->label({-for=>"addressline2"},"Address Line 2"),$g->{CGI}->textfield({-name=>"addressline2",-value=>"$addressline2",-override=>1,-size=>100}),
  $g->{CGI}->br(),
  $g->{CGI}->label({-for=>"city"},"City"),$g->{CGI}->textfield({-name=>"city",-value=>"$city",-override=>1}),
  $g->{CGI}->label({-for=>"stateprovince"},"State/Province"),$g->{CGI}->textfield({-name=>"stateprovince",-value=>"$stateprovince",-override=>1}),
  $g->{CGI}->label({-for=>"postalcode"},"postalcode"),$g->{CGI}->textfield({-name=>"postalcode",-value=>"$postalcode",-override=>1}),
  $g->{CGI}->br(),
  $g->{CGI}->label({-for=>"country"},"Country"),$g->{CGI}->popup_menu({-name=>"country",-default=>"$country",-values=>\@countries,-override=>1}),
  $g->{CGI}->br(),

  qq(\n</div>),
  $g->{CGI}->end_form();

  module_access();
  
  sub countries{
    my @retval;
    open(FIL,"<$g->{countryfile}") or die "Cannot open country-codes $!";
    while(my ($country,$twodigitcode,$threedigitcode)=split(/\,/,<FIL>)){push(@retval,"$country - $twodigitcode");}
    return @retval;
  }
}

sub module_access{
  print $g->{CGI}->start_form({-action=>"$g->{scriptname}",-method=>"get"}),
  $g->{CGI}->hidden({-name=>"username",-value=>"$g->{username}"}),
  $g->{CGI}->hidden({-name=>"action",-value=>"set_module_access",-override=>"1"});

  print $g->{CGI}->h3("Module Access"),
  "\n<div id='record'>\n",
  $g->{CGI}->start_table(-cols=>3,-width=>"70%");
    
  my $query="select name, title from interface_modules order by name;";
		     
  $sth=$g->{dbh}->prepare("$query"); $sth->execute();
  while(my($name,$title)=$sth->fetchrow_array()){
    my ($username)=$g->{dbh}->selectrow_array("select username from interface_module_access where module='$name' and username='$g->{username}'"); 
    print "<!-- username $username [$g->{username}]-->\n";
    my $checked=''; if($username eq $g->{username}){$checked='checked';}
    print $g->{CGI}->Tr(
      $g->{CGI}->td("<input type=checkbox name=$name value=true $checked>"),
      $g->{CGI}->td("$name"),
      $g->{CGI}->td(
        $g->{CGI}->a({-href=>"$g->{scriptname}?action=roles&module=$name&username=$g->{username}",
	              -title=>"modify $g->{username}\'s level of access to $name"},"roles "),
	"&nbsp;&#149;&nbsp;",
	$g->{CGI}->a({-href=>"$g->{scriptname}?action=groups&module=$name&username=$g->{username}",
	              -title=>"modify $g->{username}\'s level of access to $name"},"groups\n"),
      ),
    );
  }
  print $g->{CGI}->submit("Set $g->{username}\'s Module Access"),
  $g->{CGI}->end_form(),
  $g->{CGI}->end_table(),
  "\n </div> <!-- end record -->\n";
}

sub module_access_old{
  my @fields;
  $sth=$g->{dbh}->prepare("show fields from interface_module_users"); $sth->execute();
  while(my($f)=$sth->fetchrow_array()){unless($f eq "username" or $f eq "interface_alerts" or $f eq "interface_modules"){push(@fields,$f);}}
  my $module_query_fields="interface_users,interface_sessions,rcs_personnel,rcs_studies,rcs_notifications,rcs_settings,rcs_alerts,rcs_projects,rcs_reports";
  my @uaccess=$g->{dbh}->selectrow_array("select username,$module_query_fields from interface_module_users where username='$g->{username}'");

 print "<!--\nselect username,$module_query_fields from interface_module_users where username='$g->{uname}'\n-->\n";

  print
  $g->{CGI}->start_form({-action=>"$g->{scriptname}",-method=>"get"}),
  $g->{CGI}->hidden({-name=>"username",-value=>"$g->{username}"}),
  $g->{CGI}->hidden({-name=>"action",-value=>"set_module_access",-override=>"1"});

  print $g->{CGI}->h3("Module Access"),
  "\n<div id='record'>\n",
  $g->{CGI}->start_table(-cols=>3,-width=>"70%");

  my $i=0; foreach $a(@uaccess){
    my $checked=''; if($a eq 'true'){$checked='checked';}
    if($a ne "$g->{username}"){
      print $g->{CGI}->Tr(
        $g->{CGI}->td("<input type=checkbox name=$fields[$i-1] value=true $checked>"),
        $g->{CGI}->td("$fields[$i-1]"),
        $g->{CGI}->td(
          $g->{CGI}->a({-href=>"$g->{scriptname}?action=roles&module=$fields[$i-1]&username=$g->{username}",
	        ,-title=>"modify $g->{uname}\'s level of access to $fields[$i-1]"},"roles "),
	        "&nbsp;&#149;&nbsp;",
	        $g->{CGI}->a({-href=>"$g->{scriptname}?action=groups&module=$fields[$i-1]&username=$g->{username}",
	        ,-title=>"modify $g->{username}\'s level of access to $fields[$i-1]"},"groups\n"),
	      ),
      );
    }
    ++$i;
  }
  print "\n</ul></div> <!-- end record -->\n";

  print $g->{CGI}->submit("Set $g->{username}\'s Module Access"),
  $g->{CGI}->end_form(),
  "\n </div>\n";
}

sub groups{
  print $g->{CGI}->a({-href=>"$g->{scriptname}?action=edit&username=$g->{username}"},"Return to $g->{username}\'s record"),
  $g->{CGI}->h3({-align=>"center"},"$g->{username}'s $g->{module} groups");

  # if there is an action (removing or adding a group for a selected user, do it...
  if(defined($g->{function})){
    my $euser_groups=$g->{dbh}->selectrow_array("select groups from interface_module_access where module='$g->{module}' and username='$g->{username}'");
    if($g->{function} eq "add"){
      print "adding group: '$g->{group}' to $g->{module} for $g->{username} ...";
      $euser_groups=$euser_groups."\,$g->{group}"; $euser_groups=~s/^\,+//;
      print " $euser_groups<br />";
      $rv=$g->{dbh}->selectrow_array("select module from interface_module_access where username='$g->{username}' and module='$g->{module}'");
      if($rv){
        $g->{dbh}->do("update interface_module_access set groups=\"$euser_groups\" where module='$g->{module}' and username='$g->{username}'");
      }
      else{
        $g->{dbh}->do("insert into interface_module_access values('$g->{username}','$g->{module}','$euser_groups',NULL)");
      }
    }
    elsif($g->{function} eq "remove"){
      $euser_groups=~s/$g->{group}//; $euser_groups=~s/\,\,/\,/g;
      $g->{dbh}->do("update interface_module_access set groups=\"$euser_groups\" where module='$g->{module}' and username='$g->{username}'");
    }
    else{print $g->{CGI}->h3({-align=>"center"},"The function you have selected, '$g->{function}' does not exist."); return;}
  }

  my $total_groups=$g->{dbh}->selectrow_array("select groups from interface_modules where name='$g->{module}'");
  my $euser_groups=$g->{dbh}->selectrow_array("select groups from interface_module_access where module='$g->{module}' and username='$g->{username}'");

  unless($total_groups){print $q->h4({-align=>"center"},"This module has no groups to assign."); return;}

  my(@total_groups)=split(/\,/,$total_groups);
  my(@euser_groups)=split(/\,/,$euser_groups);

  print
  $g->{CGI}->start_table({-cols=>"2",-border=>"0",-align=>"center",-width=>"70%"}),
  $g->{CGI}->Tr($g->{CGI}->th({-align=>"center"},"unassigned"),$q->th({-align=>"center"},"assigned"));
  my $bg=$g->{bgcolor};
  foreach $group (@total_groups){
    # alternate color of table row background
    if($bg eq $g->{bgcolor}){$bg="white";}elsif($bg eq "white"){$bg=$g->{bgcolor};}
    my $status=0;
    foreach $egroup (@euser_groups){
      if($group eq $egroup){$status=1;}
    }
    if($status==1){
      print $g->{CGI}->Tr({-style=>"background-color: $bg"},
	$g->{CGI}->td("&nbsp;"),
	$g->{CGI}->td(
	  $g->{CGI}->a({-href=>"$g->{scriptname}?action=groups&function=remove&group=$group&module=$g->{module}&username=$g->{username}"},
	    $g->{CGI}->font({-style=>"color: black"},"$group"),$g->{CGI}->font({-style=>"color: red"}," << "),
        ),),
      );
    }
    else{
      print
      $g->{CGI}->Tr({-style=>"background-color: $bg"},
	$g->{CGI}->td(
	  $g->{CGI}->a({-href=>"$g->{scriptname}?action=groups&function=add&group=$group&module=$g->{module}&username=$g->{username}"},
	    $g->{CGI}->font({-style=>"color: black"},"$group"),$g->{CGI}->font({-style=>"color: green"}," >>"),
        ),),
	$g->{CGI}->td("&nbsp;"),
      );
    }
  }
  print $g->{CGI}->end_table;
}

sub roles{
  print $g->{CGI}->a({-href=>"$g->{scriptname}?action=edit&username=$g->{username}"},"Return to $g->{username}\'s record"),
  $g->{CGI}->h3({-align=>"center"},"$g->{username}'s $g->{module} roles");

  # if there is an action (removing or adding a role for a selected user, do it...
  if(defined($g->{function})){
    my $user_roles=$g->{dbh}->selectrow_array("select roles from interface_module_access where module='$g->{module}' and username='$g->{username}'");
    if($g->{function} eq "add"){
      print "adding role: '$g->{role}' to $g->{module} for $g->{username} ...";
      $user_roles=$user_roles."\,$g->{role}"; $user_roles=~s/^\,+//;
      print " $user_roles<br />";
      $rv=$g->{dbh}->selectrow_array("select module from interface_module_access where username='$g->{username}' and module='$g->{module}'");
      if($rv){
        $g->{dbh}->do("update interface_module_access set roles=\"$user_roles\" where module='$g->{module}' and username='$g->{username}'");
      }
      else{
        $g->{dbh}->do("insert into interface_module_access values('$g->{username}','$g->{module}','$user_roles',NULL)");
      }
    }
    elsif($g->{function} eq "remove"){
      $user_roles=~s/$g->{role}//; $user_roles=~s/\,\,/\,/g;
      $g->{dbh}->do("update interface_module_access set roles=\"$user_roles\" where module='$g->{module}' and username='$g->{username}'");
    }
    else{print $g->{CGI}->h3({-align=>"center"},"The function you have selected, '$g->{function}' does not exist."); return;}
  }

  my $total_roles=$g->{dbh}->selectrow_array("select roles from interface_modules where name='$g->{module}'");
  my $user_roles=$g->{dbh}->selectrow_array("select roles from interface_module_access where module='$g->{module}' and username='$g->{username}'");

  unless($total_roles){print $g->{CGI}->h4({-align=>"center"},"This module has no roles to assign."); return;}

  my(@total_roles)=split(/\,/,$total_roles);
  my(@user_roles)=split(/\,/,$user_roles);

  print
  $g->{CGI}->start_table({-cols=>"2",-border=>"0",-align=>"center",-width=>"70%"}),
  $g->{CGI}->Tr({-style=>"background-color: $g->{bgcolor}"},$g->{CGI}->th({-align=>"center"},"unassigned"),$g->{CGI}->th({-align=>"center"},"assigned"));
  my $bg=$g->{bgcolor};
  foreach $role (@total_roles){
    # alternate color of table row background
    if($bg eq $g->{bgcolor}){$bg="white";}elsif($bg eq "white"){$bg=$g->{bgcolor};}
    my $status=0;
    foreach $erole (@user_roles){
      if($role eq $erole){$status=1;}
    }
    if($status==1){
      print $g->{CGI}->Tr({-style=>"background-color: $bg"},
	$g->{CGI}->td("&nbsp;"),
	$g->{CGI}->td(
	  $g->{CGI}->a({-href=>"$g->{scriptname}?action=roles&function=remove&role=$role&module=$g->{module}&username=$g->{username}"},
	    $g->{CGI}->font({-style=>"color: black"},"$role"),$g->{CGI}->font({-style=>"color: red"}," << "),
        ),),
      );
    }
    else{
      print
      $g->{CGI}->Tr({-style=>"background-color: $bg"},
	$g->{CGI}->td(
	  $g->{CGI}->a({-href=>"$g->{scriptname}?action=roles&function=add&role=$role&module=$g->{module}&username=$g->{username}"},
	    $g->{CGI}->font({-style=>"color: black"},"$role"),$g->{CGI}->font({-style=>"color: green"}," >>"),
        ),),
	$g->{CGI}->td("&nbsp;"),
      );
    }
  }
  print $g->{CGI}->end_table;
}

sub search{
  print qq(<div id="search">),$g->{CGI}->start_form({-method=>"get",-action=>"$g->{scriptname}"}),
  $g->{CGI}->hidden({-name=>"action",-value=>"list",-override=>"1"}),
  $g->{CGI}->textfield({-name=>"query",-value=>"$g->{query}",-override=>"1"}),
  $g->{CGI}->submit("Search"),
  $g->{CGI}->end_form,
  $g->{CGI}->a({-href=>"$g->{scriptname}"},"View All&nbsp;"),
  "list last names: ";
  my $alpha="ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  for(my $digit="0"; $digit<26; ++$digit){
    my $letter=substr($alpha,$digit,1);
    if(defined($g->{letter}) and $g->{letter} eq "$letter"){
      print $g->{CGI}->a({-href=>"$g->{scriptname}?action=list&letter=$letter"},"<font color=#ff0000>$letter</font>&nbsp");
    }
    else{
      print $g->{CGI}->a({-href=>"$g->{scriptname}?action=list&letter=$letter"},"$letter&nbsp");
    }
  }
  print qq(</div> <!-- end search -->\n);
}

sub view{
  print $g->{CGI}->div({-id=>"navlinks"},
    $g->{CGI}->a({-href=>"$g->{scriptname}?action=new"},"Add a new user"),
  );

  search();
  msg("Users");
  my $query_fields="interface_users.username,interface_users.active,interface_users.email,interface_users.theme,interface_users.timeout,
  interface_users.password,interface_user_demographics.salutation,interface_user_demographics.firstname,interface_user_demographics.middle,
  interface_user_demographics.lastname,interface_user_demographics.suffix,interface_user_demographics.jobtitle,interface_user_demographics.company,
  interface_user_demographics.department,interface_user_demographics.phone,interface_user_demographics.phone,interface_user_demographics.addressline1,
  interface_user_demographics.addressline2,interface_user_demographics.city,interface_user_demographics.stateprovince,interface_user_demographics.postalcode,
  interface_user_demographics.country";

  if(defined($g->{letter})){
    $sth=$g->{dbh}->prepare("select $query_fields from interface_users left join interface_user_demographics on interface_users.username=interface_user_demographics.username
			    where interface_user_demographics.lastname regexp \"^$g->{letter}\"
			    order by interface_users.username");
  }
  elsif(defined($g->{query})){
    $sth=$g->{dbh}->prepare("select $query_fields from interface_users left join interface_user_demographics on interface_users.username=interface_user_demographics.username
			    where (lastname.interface_user_demographics regexp \"^$g->{letter}\" or username regexp \"^$g->{query}\")
			    order by interface_users.username");
  }
  else{
    $sth=$g->{dbh}->prepare("select $query_fields from interface_users left join interface_user_demographics on interface_users.username=interface_user_demographics.username
			    order by interface_users.username");
  }
  $sth->execute();
  print # ,-cols=>"7",-cellpadding=>"0",-cellspacing=>"0",-align=>"center",-width=>"750"
  $g->{CGI}->start_table({-class=>"table table-striped"}),
  $g->{CGI}->thead(
    $g->{CGI}->Tr(
      $g->{CGI}->th("username"),
      $g->{CGI}->th("last, first"),
      $g->{CGI}->th("department"),
      $g->{CGI}->th("phone"),
      $g->{CGI}->th("action"),
    ),
  );
  
  my $grey=0; my $counter=0;
  while(my($username,$active,$email,$theme,$timeout,$password,$salutation,$firstname,$middle,$lastname,$suffix,
	   $jobtitle,$company,$department,$phone,$addressline1,$addressline2,$city,$stateprovince,$postalcode,$country)=$sth->fetchrow_array()){
    if($grey==0){print "<TR class=\"even\">"; ++$grey;}else{print "<TR class=\"odd\">"; --$grey;}
    print
    $g->{CGI}->td($g->{CGI}->a({-href=>"$g->{scripname}?action=edit&username=$username",-title=>"edit $username\'s account"},"$username")),
    $g->{CGI}->td($g->{CGI}->a({-href=>"mailto:$email",-title=>"send $firstname an email ($email)"},"$lastname, $firstname $middle $suffix")),
    $g->{CGI}->td("$department"),$g->{CGI}->td("$phone");
    print "<td>";
    if($g->{my_roles}=~m/delete/ and $username ne 'dev' and $username ne 'bciv'){
      print $g->{CGI}->a({-href=>"$g->{scriptname}?action=delete&username=$username",-title=>"delete $username\'s account"},"delete ");
    }
    print $g->{CGI}->a({-href=>"mailto:$email",-title=>"send $firstname an email ($email)"},"email");

    print "</td></TR>";
    ++$counter;
  }
  print $g->{CGI}->end_table();
  if($counter==0){
    print $g->{CGI}->start_table({-cols=>"1",-cellpadding=>"0",-cellspacing=>"0",-align=>"center",-width=>"70%"}),
    $g->{CGI}->Tr($g->{CGI}->td($g->{CGI}->h3({-align=>"center"},"No user records found that start with \"$g->{letter}\"."))),
    $g->{CGI}->end_table();
  }
}

sub msg{ my ($msg)=@_; print $g->{CGI}->h3({-align=>"center"},"$msg");}
