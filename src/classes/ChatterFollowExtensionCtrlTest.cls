@isTest(seeAllData=true)
public class ChatterFollowExtensionCtrlTest{

	public testmethod static void test_constoractor(){

		ChatterUserFollowSetting__c setting = ChatterUserFollowSetting__c.getInstance();
        if(setting.Id != null){
        	delete setting;
        }	

		ApexPages.StandardController stdCtrl = null;
		ChatterFollowExtensionController ctrl = null;

		User u = new User();
		u.Id = UserInfo.getUserId();
		u.Username = UserInfo.getUserName();

		//カスタム設定がない場合
        stdCtrl = new ApexPages.StandardController(u);
        ctrl = new ChatterFollowExtensionController( stdCtrl );
        System.assertEquals(5000 , ctrl.insertLimit);

		//カスタム設定に数値が設定済み
		setting = ChatterUserFollowSetting__c.getInstance();
        setting.BatchSize__c = 55;
        insert setting;

        stdCtrl = new ApexPages.StandardController(u);
        ctrl = new ChatterFollowExtensionController( stdCtrl );
        System.assertEquals(55 , ctrl.insertLimit);

	}

	public testmethod static void test_refreshFollowCount(){

		ApexPages.StandardController stdCtrl = null;
		ChatterFollowExtensionController ctrl = null;
		Pagereference returnPage = null;

		User u = new User();
		u.Id = UserInfo.getUserId();
		u.Username = UserInfo.getUserName();

        stdCtrl = new ApexPages.StandardController(u);
        ctrl = new ChatterFollowExtensionController( stdCtrl );
		
		Test.startTest();

        //通常パターン
        returnPage = ctrl.refreshFollowCount();
        System.assertEquals( null , returnPage );
		System.assert( ctrl.allUserNum >= ctrl.followUserNum );

		//最大数到達パターン
		ChatterFollowExtensionController.USER_SELECT_LIMIT = 1;
		returnPage = ctrl.refreshFollowCount();
        System.assertEquals( null , returnPage );
		System.assert( ctrl.allUserNum >= ctrl.followUserNum );
		System.assert( ctrl.isUserLimit );

		Test.stopTest();

	}

	public testmethod static void test_getUserList(){

		Map<String , Object> resultMap = null;

		ChatterFollowExtensionController.USER_SELECT_LIMIT = 1;
		ChatterFollowExtensionController.ITEMS_PER_PAGE = 1;

		//フォロー情報が存在する場合は予め削除しておく
		List<User> u = [select Id  from User 
            where Id != :UserInfo.getUserId() and IsActive = true and 
                Profile.UserLicense.LicenseDefinitionKey  in ('SFDC' , 'AUL' , 'CSN_User')
            order by LastLoginDate desc
            limit 1];
        if(u.size() > 0){
			List <EntitySubscription> followers = [
	            SELECT Id FROM EntitySubscription WHERE SubscriberId = :UserInfo.getUserId() and ParentId = :u[0].Id 
	        ];
	        if( followers.size() > 0){
	        	delete followers;
	        }
    	}

		Test.startTest();

		resultMap = ChatterFollowExtensionController.getUserList( UserInfo.getUserId() , 100000 );

		system.assertEquals( 1 , ((List<User>)resultMap.get('list')).size() );
		system.assertEquals( 1 , ((Integer)resultMap.get('pagenum')));
		system.assert( 1 <= ((Integer)resultMap.get('pagesize')));

		Test.stopTest();

	}

	public testmethod static void test_followUser(){

		Integer result;

		List<User> u = [select Id  from User 
                where Id != :UserInfo.getUserId() and IsActive = true and 
                    Profile.UserLicense.LicenseDefinitionKey  in ('SFDC' , 'AUL' , 'CSN_User')
                order by LastLoginDate desc
                limit 1];

        List<Id> ids = new List<Id>();
        if(u.size() > 0){
	        ids.add(u[0].Id);
           	List <EntitySubscription> followers = [
            	SELECT Id FROM EntitySubscription WHERE SubscriberId = :UserInfo.getUserId() and ParentId = :u[0].Id 
        	];
        	if( followers.size() > 0){
        		delete followers;
        	}
        }

        Test.startTest();

        //フォローされることを確認
		result = ChatterFollowExtensionController.followUser( UserInfo.getUserId() , ids , 10);
		if(ids.size() > 0){
			system.assertEquals( 1 , result );			
			system.assertEquals( 1 , [ SELECT Id, ParentId FROM EntitySubscription 
										WHERE SubscriberId = :UserInfo.getUserId() and ParentId = :ids[0] 
        						].size() );
		}else{
			system.assertEquals( 0 , result );			
			return;
		}

		//フォロー済みの場合は0件であること
		result = ChatterFollowExtensionController.followUser( UserInfo.getUserId() , ids , 10);
		system.assertEquals( 1 , [ SELECT Id, ParentId FROM EntitySubscription 
										WHERE SubscriberId = :UserInfo.getUserId() and ParentId = :ids[0] 
        						].size() );
		system.assertEquals( 0 , result );			
	
        Test.stopTest();

	}

	public testmethod static void test_followAllUser(){

		Integer result;

		ChatterUserFollowSetting__c setting = ChatterUserFollowSetting__c.getInstance();
        if(setting.Id != null){
        	delete setting;
        	setting = ChatterUserFollowSetting__c.getInstance();
        }
        setting.BatchSize__c = 30;
        setting.licensedefinition1__c = 'hogehoge';
		setting.licensedefinition2__c = 'piyopiyo';
		setting.licensedefinition3__c = 'hogehoge';
		insert setting;

		List<User> u = [select Id  from User 
                where Id != :UserInfo.getUserId() and IsActive = true and 
                    Profile.UserLicense.LicenseDefinitionKey in ('SFDC' , 'AUL' , 'CSN_User')
                order by LastLoginDate desc
                limit 1];

        List<Id> ids = new List<Id>();
        if(u.size() > 0){
	        ids.add(u[0].Id);
           	List <EntitySubscription> followers = [
            	SELECT Id FROM EntitySubscription WHERE SubscriberId = :UserInfo.getUserId() and ParentId = :u[0].Id 
        	];
        	if( followers.size() > 0){
        		delete followers;
        	}
        }

        Test.startTest();

        //フォローされることを確認
        ChatterFollowExtensionController.USER_SELECT_LIMIT = 2;
		result = ChatterFollowExtensionController.followAllUser( UserInfo.getUserId() , 2);
		if(ids.size() > 0){
			system.assert( result >= 1 );			
			system.assertEquals( 1 , [ SELECT Id, ParentId FROM EntitySubscription 
										WHERE SubscriberId = :UserInfo.getUserId() and ParentId = :ids[0] 
        						].size() );
		}else{
			system.assertEquals( 0 , result );
			return;
		}

		//フォロー済みの場合のパターン
		result = ChatterFollowExtensionController.followUser( UserInfo.getUserId() , ids , 2);
		system.assertEquals( 1 , [ SELECT Id, ParentId FROM EntitySubscription 
										WHERE SubscriberId = :UserInfo.getUserId() and ParentId = :ids[0] 
        						].size() );
		system.assertEquals( 0 , result );	

        Test.stopTest();

	}

}