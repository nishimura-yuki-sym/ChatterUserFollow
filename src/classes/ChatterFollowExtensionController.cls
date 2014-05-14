global with sharing class ChatterFollowExtensionController {

    //本来は定数にしたいがテスト用に開放
    @TestVisible private static Integer USER_SELECT_LIMIT  = 5000;
    @TestVisible private static Integer ITEMS_PER_PAGE     = 50;    
    @TestVisible private static Integer DEFAULT_ENTRY_INSERT_LIMIT = 5000;    

    private Integer ENTRY_INSERT_LIMIT = DEFAULT_ENTRY_INSERT_LIMIT;
    public Integer insertLimit { get{return ENTRY_INSERT_LIMIT;} }

    public User followerUser { get; set; }
    public Integer allUserNum{ get; set; }
    public Integer followUserNum{ get; set; } 
    public Boolean isUserLimit{ get; set; } 

    public ChatterFollowExtensionController(ApexPages.StandardController stdController) {
        //フォロワーユーザを取得
        if(!Test.isRunningTest()) {
            stdController.addFields( new String[]{ 'Id' , 'Name'});
        }
        followerUser = (User)stdController.getRecord();

        ENTRY_INSERT_LIMIT = getInsertSize();

    }

    public Pagereference refreshFollowCount(){
        
        //外部ユーザ以外を取得
        List<User> users = getUserList( followerUser.Id  );
        this.isUserLimit = false;
        if(users.size() > USER_SELECT_LIMIT){
            users.remove( users.size() - 1);
            isUserLimit = true;
        }
        List<Id> ids = new List<Id>();
        for(User u : users){
            ids.add(u.Id);
        }
        List<EntitySubscription> followers = [
            SELECT Id, ParentId FROM EntitySubscription WHERE SubscriberId = :followerUser.Id and ParentId in :ids 
        ];

        this.allUserNum = users.size();
        this.followUserNum = followers.size();

        return null;

    }
  
    /**
     * ページ番号を指定してユーザリストを取得
     */
    @RemoteAction
    global static Map<String , Object>  getUserList( Id followerId , Integer pagenum ){
        Map<String , Object> resultMap = new Map<String , Object>();

        List<User> users = getNotFollowUserList(followerId);

        Integer startIndex = (pagenum-1) * ITEMS_PER_PAGE;
        //範囲外の場合は最初のページを指す
        if(users.size() <= startIndex || startIndex < 0){
            startIndex  = 0;
            pagenum = 1;
        }

        //データを指定数分だけに絞る
        List<User> resultList = new List<User>();
        for(integer i=0;i<ITEMS_PER_PAGE;i++){
            integer index = (i+startIndex);
            if(index >= users.size()){
                break;
            }
            User u = users.get(index);
            resultList.add(u);
        }
        
        resultMap.put('list' , resultList);
        resultMap.put('pagenum' , pagenum);
        resultMap.put('pagesize' , (Math.mod(users.size() , ITEMS_PER_PAGE) == 0) ? users.size() / ITEMS_PER_PAGE : (users.size() / ITEMS_PER_PAGE)+1 );

        return resultMap ;
    }

    /**
     * 指定IDのユーザをまとめてフォロー
     * return insert数
     */
    @RemoteAction
    global static Integer followUser( Id followerId , List<Id> userIds , Integer batchSize){
        return follow(followerId , userIds , batchSize); 
    }

    /**
     * フォローしていないユーザをまとめてフォロー
     * return insert数
     */
    @RemoteAction
    global static Integer followAllUser( Id followerId , Integer batchSize){
        return follow(followerId , null , batchSize); 
    }

    private static boolean verifyUser(Id followerId){
        List<User> u = [select Id from User where Id = :followerId and IsActive = true];
        return u.size() >= 1;
    }
    private static List<User> getUserList(Id followerId){
        //外部ユーザ以外を取得
        return [select Id , Username , SmallPhotoUrl,Email from User 
                where Id != :followerId and IsActive = true and 
                    Profile.UserLicense.LicenseDefinitionKey in :getLicenseDefinition()
                order by LastLoginDate desc
                limit :(USER_SELECT_LIMIT + 1)];
    }
    private static List<User> getNotFollowUserList(Id followerId){

        List<User> resultList = new List<User>();
        
        List<User> allUsers = getUserList( followerId );
        List<Id> ids = new List<Id>();
        for(User u : allUsers){
            ids.add(u.Id);
        }
        List <EntitySubscription> followers = [
            SELECT Id, ParentId FROM EntitySubscription WHERE SubscriberId = :followerId and ParentId in :ids 
        ];
        
        Set<Id> registerSet = new Set<Id>();
        for(EntitySubscription e : followers){
           registerSet.add(e.ParentId);
        }
        
        List<EntitySubscription> insertEntry = new List<EntitySubscription>();
        for(User u : allUsers){
            if(!registerSet.contains(u.Id)){
                resultList.add( u );
            }
        }  
        return resultList;
    }

    private static Integer follow( Id followerId  , List<Id> userIds , Integer batchSize){

        //ParentId = フォローされているユーザ
        //SubscriberId = フォローしているユーザ
        if(batchSize == null || batchSize <= 0){
            batchSize = DEFAULT_ENTRY_INSERT_LIMIT;
        }

        List<User> users = getNotFollowUserList( followerId );
        Set<Id> ids = null;
        if(userIds != null){
            ids = new Set<Id>();
            for(Id uid : userIds){
                ids.add(uid);        
            }
        }
        
        List<EntitySubscription> insertEntry = new List<EntitySubscription>();
        for(User u : users){
            if( ids == null || ids.contains(u.Id) ){
                EntitySubscription entry = new EntitySubscription();
                entry.ParentId = u.Id;
                entry.SubscriberId = followerId;
                insertEntry.add(entry);
                if(insertEntry.size() >= batchSize){
                    break;
                }
            }
        }                                                                    
        
        if(insertEntry.size() > 0){
            insert insertEntry;    
        }
    
        return insertEntry.size();
       
    }

    private static List<String> getLicenseDefinition(){
        
        List<String> result = new List<String>();

        //フォロー検索対象ユーザライセンスの固定値
        Set<String> lisenceSet = new Set<String>{
            'SFDC' , 'CSN_User' , 'AUL'
        };

        
        ChatterUserFollowSetting__c setting = ChatterUserFollowSetting__c.getInstance();
        if(setting.Name != null){
            for(Integer i=0;i<10;i++){
                String tmp = String.valueOf(setting.get('licensedefinition' +(i+1)+'__c'));
                if(tmp != null && !lisenceSet.contains(tmp)){
                    lisenceSet.add(tmp);
                }
            }
        }
        for( String definition : lisenceSet){
            result.add(definition);
        }

        return result;

    }

    private static Integer getInsertSize(){
        ChatterUserFollowSetting__c setting = ChatterUserFollowSetting__c.getInstance();
        if(setting.BatchSize__c != null && setting.BatchSize__c >= 1){
            return Integer.valueOf(setting.BatchSize__c);
        }
        return DEFAULT_ENTRY_INSERT_LIMIT;
    }

}