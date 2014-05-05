global with sharing class ChatterFollowExtensionController {

    public User followerUser { get; set; }
    public List<User> users{get; set;}

    public ChatterFollowExtensionController(ApexPages.StandardController stdController) {
        //フォロワーユーザを取得
        followerUser = (User)stdController.getRecord();
    }

    public Pagereference init(){
  
        users = [select Id , Name , SmallPhotoUrl,FullPhotoUrl,Email from User limit :Limits.getLimitQueries()];
        //IsActive  , Email
        return null;
    }
  

    public Pagereference follow(){
    
        try{
    
            Id uid = UserInfo.getUserId();
        
            //ParentId = フォローされているユーザ
            //SubscriberId = フォローしているユーザ
            
            List <User> users = [select Id from User];
            List <EntitySubscription> followers = [
                SELECT Id, ParentId FROM EntitySubscription WHERE SubscriberId = :uid
            ];
            
            
            Map<Id , EntitySubscription> registeredEntryMap = new Map<Id , EntitySubscription>();
            for(EntitySubscription e : followers){
               registeredEntryMap.put(e.ParentId , e);
            }
            
            
            List<EntitySubscription> insertEntry = new List<EntitySubscription>();
            for(User u : users){
                if(u.Id == uid){
                    continue;
                }
                if(!registeredEntryMap.containsKey(u.Id)){
                    EntitySubscription entry = new EntitySubscription();
                    entry.ParentId = u.Id;
                    entry.SubscriberId = uid;
                    insertEntry.add(entry);
                }
            }                                                                    
            
            if(insertEntry.size() > 0){
                insert insertEntry;    
            }
     
        }catch(Exception e){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));       
        }
        
        return null;
        
    }
    

}