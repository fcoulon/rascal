package org.rascalmpl.tasks.internal;

import org.eclipse.imp.pdb.facts.IValue;
import org.rascalmpl.tasks.IDependencyListener;
import org.rascalmpl.tasks.IFact;
import org.rascalmpl.tasks.internal.AbstractDepFact;

import static org.rascalmpl.tasks.IDependencyListener.Change.*;
/**
 * This class implements fact storage for strongly referenced facts (i.e., a fact will never be removed
 * by the garbarge collector unless it is explicitly removed from the database) with fine-grained
 * tracking of dependencies.
 * 
 * @author anya
 *
 */
public class FineGrainedStrongFact<V> extends AbstractDepFact<V,V> {

	public FineGrainedStrongFact(Object key) {
		super(key);
	}

	/* (non-Javadoc)
	 * @see org.rascalmpl.eclipse.db.IFact#setValue(org.eclipse.imp.pdb.facts.T)
	 */
	@Override
	public synchronized void setValue(V val) {
		V oldValue = value;
		value = val;
		status = FACT_OK;
		if(oldValue != null &&
			!(value instanceof IValue ? ((IValue)oldValue).isEqual((IValue)val) : oldValue.equals(value)))
					notifyChanged();
	}

	@Override
	public synchronized void changed(IFact<?> fact, Change change) {
		switch(change) {
		case CHANGED:
			if(status < FACT_DEPS_CHANGED) {
				status = FACT_DEPS_CHANGED;
				notifyInvalidated();
			}
			break;
		case INVALIDATED:
			if(status < FACT_DEPS_INVALID) {
				status = FACT_DEPS_INVALID;
				notifyInvalidated();
			}
			break;
		case REMOVED:
			if(status < FACT_DEPS_CHANGED) {
				dependencies.remove(fact);
				status = FACT_DEPS_CHANGED;
				notifyInvalidated();
			}
			break;
		}
	}



	/**
	 * Disposing of a fact means telling all our dependencies to notify our
	 * dependents instead about any changes. This is done when the fact itself
	 * is still useful, but we don't want to keep it in memory anymore. (We
	 * basically link ourselves out of the dependency chain)
	 */
	public void dispose() {
		for(IFact<?> f : dependencies) {
			f.unregisterListener(this);
		}
		for(IDependencyListener l : listeners) {
			l.changed(this, REMOVED);
		}

		dependencies.clear();
		listeners.clear();
		value = null;
	}


	@Override
	public synchronized V getValue() {
		if(status == FACT_OK)
			return value;
		else
			return null;
	}



	@SuppressWarnings("unchecked")
	@Override
	public synchronized void updateFrom(IFact<V> fact) {
		synchronized(fact) {
			if(fact instanceof AbstractDepFact<?,?>) {
				AbstractDepFact<?,?> f = (AbstractDepFact<?,?>)fact;
				for(IFact<?> df : dependencies) {
					if(!f.dependencies.contains(df)) {
						dependencies.remove(df);
						df.unregisterListener(this);
					}
				}
				for(IFact<?> df : f.dependencies) {
					if(!dependencies.contains(df)) {
						dependencies.add(df);
						df.registerListener(this);
					}
				}
				if(f.value == null)
					value = null;
				else
					value = (V)f.value;
				//else
				//	throw new ImplementationError("Trying to update from fact with incompatible value types");
			}
			
		}
	}

}
