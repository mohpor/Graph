/**
* Copyright (C) 2015 GraphKit, Inc. <http://graphkit.io> and other GraphKit contributors.
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero General Public License as published
* by the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero General Public License for more details.
*
* You should have received a copy of the GNU Affero General Public License
* along with this program located at the root of the software package
* in a file called LICENSE.  If not, see <http://www.gnu.org/licenses/>.
*
* GKGraph
*
* Manages Nodes in the persistent layer, as well as, offers watchers to monitor
* changes in the persistent layer.
*/

import CoreData

struct GKGraphUtility {
	static let entityStoreName: String = "GraphKit.sqlite"
	static let entityEntityIndexName: String = "GKManagedEntity"
	static let entityEntityDescriptionName: String = "GKManagedEntity"
	static let managedEntityObjectClassName: String = "GKManagedEntity"
    static let entityActionIndexName: String = "GKManagedAction"
    static let entityActionDescriptionName: String = "GKManagedAction"
    static let managedActionObjectClassName: String = "GKManagedAction"
    static let entityBondIndexName: String = "GKManagedBond"
    static let entityBondDescriptionName: String = "GKManagedBond"
    static let managedBondObjectClassName: String = "GKManagedBond"
}

@objc(GKGraphDelegate)
public protocol GKGraphDelegate {
    optional func graph(graph: GKGraph!, didInsertEntity entity: GKEntity!)
    optional func graph(graph: GKGraph!, didUpdateEntity entity: GKEntity!)
    optional func graph(graph: GKGraph!, didArchiveEntity entity: GKEntity!)
    optional func graph(graph: GKGraph!, didInsertAction action: GKAction!)
    optional func graph(graph: GKGraph!, didUpdateAction action: GKAction!)
    optional func graph(graph: GKGraph!, didArchiveAction action: GKAction!)
    optional func graph(graph: GKGraph!, didInsertBond bond: GKBond!)
    optional func graph(graph: GKGraph!, didUpdateBond bond: GKBond!)
    optional func graph(graph: GKGraph!, didArchiveBond bond: GKBond!)
}

@objc(GKGraph)
public class GKGraph : NSObject {
	var watching: Dictionary<String, Array<String>>
	var masterPredicate: NSPredicate?

	public weak var delegate: GKGraphDelegate?

    /**
    * init
    * Initializer for the Object.
    */
    override public init() {
		watching = Dictionary<String, Array<String>>()
		super.init()
	}

    /**
    * deinit
    * Deinitializes the Object, mainly removing itself as an Observer for NSNotifications.
    */
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

    /**
    * watch
    * Attaches the Graph instance to Notification center in order to Observe changes for an Entity with the spcified type.
    */
    public func watch(Entity type: String!) {
        addWatcher("type", value: type, index: GKGraphUtility.entityEntityIndexName, entityDescriptionName: GKGraphUtility.entityEntityDescriptionName, managedObjectClassName: GKGraphUtility.managedEntityObjectClassName)
    }

    /**
    * watch
    * Attaches the Graph instance to Notification center in order to Observe changes for an Action with the spcified type.
    */
    public func watch(Action type: String!) {
        addWatcher("type", value: type, index: GKGraphUtility.entityActionIndexName, entityDescriptionName: GKGraphUtility.entityActionDescriptionName, managedObjectClassName: GKGraphUtility.managedActionObjectClassName)
    }

    /**
    * watch
    * Attaches the Graph instance to Notification center in order to Observe changes for a Bond with the spcified type.
    */
    public func watch(Bond type: String!) {
        addWatcher("type", value: type, index: GKGraphUtility.entityBondIndexName, entityDescriptionName: GKGraphUtility.entityBondDescriptionName, managedObjectClassName: GKGraphUtility.managedBondObjectClassName)
    }

    /**
    * save
    * Updates the persistent layer by processing all the changes in the Graph.
    */
	public func save(completion: (succeeded: Bool, error: NSError?) -> ()) {
		managedObjectContext.performBlock {
			if !self.managedObjectContext.hasChanges {
				completion(succeeded: true, error: nil)
				return
			}

			let (result, error): (Bool, NSError?) = self.validateConstraints()
			if !result {
				completion(succeeded: result, error: error)
                println("[GraphKit Error: Constraint is not satisfied.]")
				return
			}

			var saveError: NSError?
			completion(succeeded: self.managedObjectContext.save(&saveError), error: error)
			assert(nil == error, "[GraphKit Error: Saving to private context.]")
		}
	}

	public func managedObjectContextDidSave(notification: NSNotification) {
		let incomingManagedObjectContext: NSManagedObjectContext = notification.object as NSManagedObjectContext
		let incomingPersistentStoreCoordinator: NSPersistentStoreCoordinator = incomingManagedObjectContext.persistentStoreCoordinator!

		let userInfo = notification.userInfo

		// inserts
		let insertedSet: NSSet = userInfo?[NSInsertedObjectsKey] as NSSet
		let	inserted: NSMutableSet = insertedSet.mutableCopy() as NSMutableSet

		inserted.filterUsingPredicate(masterPredicate!)

		if 0 < inserted.count {
			let nodes: Array<NSManagedObject> = inserted.allObjects as [NSManagedObject]
			for node: NSManagedObject in nodes {
				let className = String.fromCString(object_getClassName(node))
				if nil == className {
					println("[GraphKit Error: Cannot get Object Class name.]")
					continue
				}
				switch(className!) {
					case "GKManagedEntity_GKManagedEntity_":
						delegate?.graph?(self, didInsertEntity: GKEntity(entity: node as GKManagedEntity))
						break
                    case "GKManagedAction_GKManagedAction_":
                        delegate?.graph?(self, didInsertAction: GKAction(action: node as GKManagedAction))
                        break
                    case "GKManagedBond_GKManagedBond_":
                        delegate?.graph?(self, didInsertBond: GKBond(bond: node as GKManagedBond))
                        break
					default:
						assert(false, "[GraphKit Error: GKGraph observed an object that is invalid.]")
				}
			}
		}

		// updates
		let updatedSet: NSSet = userInfo?[NSUpdatedObjectsKey] as NSSet
		let	updated: NSMutableSet = updatedSet.mutableCopy() as NSMutableSet
		updated.filterUsingPredicate(masterPredicate!)

		if 0 < updated.count {
			let nodes: Array<NSManagedObject> = updated.allObjects as [NSManagedObject]
			for node: NSManagedObject in nodes {
				let className = String.fromCString(object_getClassName(node))
				if nil == className {
                    println("[GraphKit Error: Cannot get Object Class name.]")
					continue
				}
				switch(className!) {
					case "GKManagedEntity_GKManagedEntity_":
						delegate?.graph?(self, didUpdateEntity: GKEntity(entity: node as GKManagedEntity))
						break
                    case "GKManagedAction_GKManagedAction_":
                        delegate?.graph?(self, didUpdateAction: GKAction(action: node as GKManagedAction))
                        break
                    case "GKManagedBond_GKManagedBond_":
                        delegate?.graph?(self, didUpdateBond: GKBond(bond: node as GKManagedBond))
                        break
                    default:
						assert(false, "[GraphKit Error: GKGraph observed an object that is invalid.]")
				}
			}
		}

		// deletes
		let deletedSet: NSSet? = userInfo?[NSDeletedObjectsKey] as? NSSet

		if nil == deletedSet? {
			return
		}

		var	deleted: NSMutableSet = deletedSet!.mutableCopy() as NSMutableSet
		deleted.filterUsingPredicate(masterPredicate!)

		if 0 < deleted.count {
			let nodes: Array<NSManagedObject> = deleted.allObjects as [NSManagedObject]
			for node: NSManagedObject in nodes {
				let className = String.fromCString(object_getClassName(node))
				if nil == className {
                    println("[GraphKit Error: Cannot get Object Class name.]")
					continue
				}
				switch(className!) {
					case "GKManagedEntity_GKManagedEntity_":
						delegate?.graph?(self, didArchiveEntity: GKEntity(entity: node as GKManagedEntity))
						break
                    case "GKManagedAction_GKManagedAction_":
                        delegate?.graph?(self, didArchiveAction: GKAction(action: node as GKManagedAction))
                        break
                    case "GKManagedBond_GKManagedBond_":
                        delegate?.graph?(self, didArchiveBond: GKBond(bond: node as GKManagedBond))
                        break
                    default:
						assert(false, "[GraphKit Error: GKGraph observed an object that is invalid.]")
				}
			}
		}
	}

    // make thread safe by creating this asynchronously
    var managedObjectContext: NSManagedObjectContext {
        struct GKGraphManagedObjectContext {
            static var onceToken: dispatch_once_t = 0
            static var managedObjectContext: NSManagedObjectContext!
        }
        dispatch_once(&GKGraphManagedObjectContext.onceToken) {
            GKGraphManagedObjectContext.managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
            GKGraphManagedObjectContext.managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        }
        return GKGraphManagedObjectContext.managedObjectContext
    }

    // Managed Object Model
    private var managedObjectModel: NSManagedObjectModel {
        struct GKGraphManagedObjectModel {
            static var onceToken: dispatch_once_t = 0
            static var managedObjectModel: NSManagedObjectModel!
        }
        dispatch_once(&GKGraphManagedObjectModel.onceToken) {
            GKGraphManagedObjectModel.managedObjectModel = NSManagedObjectModel()

            var entityEntityDescription: NSEntityDescription = NSEntityDescription()
            var entityEntityProperties: Array<AnyObject> = Array<AnyObject>()
            entityEntityDescription.name = GKGraphUtility.entityEntityDescriptionName
            entityEntityDescription.managedObjectClassName = GKGraphUtility.managedEntityObjectClassName

            var entityActionDescription: NSEntityDescription = NSEntityDescription()
            var entityActionProperties: Array<AnyObject> = Array<AnyObject>()
            entityActionDescription.name = GKGraphUtility.entityActionDescriptionName
            entityActionDescription.managedObjectClassName = GKGraphUtility.managedActionObjectClassName

            var entityBondDescription: NSEntityDescription = NSEntityDescription()
            var entityBondProperties: Array<AnyObject> = Array<AnyObject>()
            entityBondDescription.name = GKGraphUtility.entityBondDescriptionName
            entityBondDescription.managedObjectClassName = GKGraphUtility.managedBondObjectClassName

            var nodeClass: NSAttributeDescription = NSAttributeDescription()
            nodeClass.name = "nodeClass"
            nodeClass.attributeType = .StringAttributeType
            nodeClass.optional = false
            entityEntityProperties.append(nodeClass)
            entityActionProperties.append(nodeClass.copy() as NSAttributeDescription)
            entityBondProperties.append(nodeClass.copy() as NSAttributeDescription)

            var type: NSAttributeDescription = NSAttributeDescription()
            type.name = "type"
            type.attributeType = .StringAttributeType
            type.optional = false
            entityEntityProperties.append(type)
            entityActionProperties.append(type.copy() as NSAttributeDescription)
            entityBondProperties.append(type.copy() as NSAttributeDescription)

            var createdDate: NSAttributeDescription = NSAttributeDescription()
            createdDate.name = "createdDate"
            createdDate.attributeType = .DateAttributeType
            createdDate.optional = false
            entityEntityProperties.append(createdDate)
            entityActionProperties.append(createdDate.copy() as NSAttributeDescription)
            entityBondProperties.append(createdDate.copy() as NSAttributeDescription)

            var properties: NSAttributeDescription = NSAttributeDescription()
            properties.name = "properties"
            properties.attributeType = .TransformableAttributeType
            properties.attributeValueClassName = "Dictionary"
            properties.optional = false
            properties.storedInExternalRecord = true
            entityEntityProperties.append(properties)
            entityActionProperties.append(properties.copy() as NSAttributeDescription)
            entityBondProperties.append(properties.copy() as NSAttributeDescription)

            entityEntityDescription.properties = entityEntityProperties
            entityActionDescription.properties = entityActionProperties
            entityBondDescription.properties = entityBondProperties
            GKGraphManagedObjectModel.managedObjectModel.entities = [
                    entityEntityDescription,
                    entityActionDescription,
                    entityBondDescription
            ]
        }
        return GKGraphManagedObjectModel.managedObjectModel!
    }

    private var persistentStoreCoordinator: NSPersistentStoreCoordinator {
        struct GKGraphPersistentStoreCoordinator {
            static var onceToken: dispatch_once_t = 0
            static var persistentStoreCoordinator: NSPersistentStoreCoordinator!
        }
        dispatch_once(&GKGraphPersistentStoreCoordinator.onceToken) {
            let storeURL = self.applicationDocumentsDirectory.URLByAppendingPathComponent(GKGraphUtility.entityStoreName)
            var error: NSError?
            GKGraphPersistentStoreCoordinator.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
            var options: Dictionary = [NSReadOnlyPersistentStoreOption: false, NSSQLitePragmasOption: ["journal_mode": "DELETE"]];
            if nil == GKGraphPersistentStoreCoordinator.persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: options as NSDictionary, error: &error) {
                assert(nil == error, "Error saving in private context")
            }
        }
        return GKGraphPersistentStoreCoordinator.persistentStoreCoordinator!
    }

    private var applicationDocumentsDirectory: NSURL {
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.endIndex - 1] as NSURL
    }
    
	private func prepareForObservation() {
		NSNotificationCenter.defaultCenter().removeObserver(self, name: NSManagedObjectContextDidSaveNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "managedObjectContextDidSave:", name: NSManagedObjectContextDidSaveNotification, object: managedObjectContext)
	}

	private func addPredicateToContextWatcher(entityDescription: NSEntityDescription!, predicate: NSPredicate!) {
		var entityPredicate: NSPredicate = NSPredicate(format: "entity.name == %@", entityDescription.name!)!
		var predicates: Array<NSPredicate> = [entityPredicate, predicate]
		let finalPredicate: NSPredicate = NSCompoundPredicate.andPredicateWithSubpredicates(predicates)
		masterPredicate = nil != masterPredicate ? NSCompoundPredicate.orPredicateWithSubpredicates([masterPredicate!, finalPredicate]) : finalPredicate
	}

	private func validateConstraints() -> (Bool, NSError?) {
		var result: (success: Bool, error: NSError?) = (true, nil)
		return result
	}

	private func isWatching(key: String!, index: String!) -> Bool {
		var watch: Array<String> = nil != watching[index] ? watching[index]! as Array<String> : Array<String>()
		for item: String in watch {
			if item == key {
				return true
			}
		}
		watch.append(key)
		watching[index] = watch
		return false
	}

	private func addWatcher(key: String!, value: String!, index: String!, entityDescriptionName: String!, managedObjectClassName: String!) {
		if true == isWatching(value, index: index) {
			return
		}
		var entityDescription: NSEntityDescription = NSEntityDescription()
		entityDescription.name = entityDescriptionName
		entityDescription.managedObjectClassName = managedObjectClassName
		var predicate: NSPredicate = NSPredicate(format: "%K == %@", key as NSString, value as NSString)!
		addPredicateToContextWatcher(entityDescription, predicate: predicate)
		prepareForObservation()
	}
}